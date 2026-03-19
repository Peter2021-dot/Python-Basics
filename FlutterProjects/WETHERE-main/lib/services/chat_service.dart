import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_model.dart';
import 'dart:async';
import 'notification_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  // Get or Create a chat between the current user and another user for a specific journey
  Future<String> getOrCreateChat(String journeyId, String otherUserId, {String? journeyTitle}) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) throw Exception('Not authenticated');

    // Check if chat already exists
    // We filter by journeyId and participants. 
    // Since Firestore array-contains only allows one value, we have to handle this carefully.
    // A composite ID is easiest: sort(uid1, uid2) + journeyId?
    // Or just query participants.
    
    // Let's use a determined ID for 1-on-1 chat per journey:
    // This allows easy lookup without querying.
    final List<String> ids = [myId, otherUserId]..sort();
    final String chatId = '${journeyId}_${ids[0]}_${ids[1]}';
    
    // Safe check using query to avoid "Permission Denied" if doc doesn't exist
    // (Direct doc.get() fails on missing docs because rules can't check 'resource.data')
    final query = await _firestore
        .collection('chats')
        .where(FieldPath.documentId, isEqualTo: chatId)
        .limit(1)
        .get();
    
    if (query.docs.isEmpty) {
      // Create it
      await _firestore.collection('chats').doc(chatId).set({
        'participants': ids,
        'journeyId': journeyId,
        'journeyTitle': journeyTitle ?? 'Journey',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastSenderId': '',
        'participantData': { // Snapshot for list display
          myId: {}, 
          otherUserId: {},
        }
      });
    }
    
    return chatId;
  }

  // Send a message
  Future<void> sendMessage(String chatId, String content) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    final batch = _firestore.batch();
    
    final msgRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();
    
    // We need journeyId and receiverId... 
    // Ideally we pass the ChatMessage object, but simpler to construct here if we read chat metadata.
    // For efficiency, let's assume the caller passes the minimal needed or we just pass content.
    // Actually, to construct a proper ChatMessage model we need ids.
    
    // Let's read the chat doc first to get participants/journeyId? 
    // Or simpler: pass these as args.
    // But since I designed `sendMessage(chatId, content)`, let's read the doc.
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    if (!chatDoc.exists) return;
    
    final data = chatDoc.data() as Map<String, dynamic>;
    final List<dynamic> participants = data['participants'];
    final String receiverId = participants.firstWhere((id) => id != myId);
    final String journeyId = data['journeyId'];

    final message = ChatMessage(
      journeyId: journeyId,
      senderId: myId,
      receiverId: receiverId,
      content: content,
      timestamp: DateTime.now(),
    );

    batch.set(msgRef, message.toMap());

    // Update Chat metadata
    batch.update(_firestore.collection('chats').doc(chatId), {
      'lastMessage': content,
      'lastSenderId': myId,
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadCount_$receiverId': FieldValue.increment(1),
    });

    await batch.commit();

    // Send notification to receiver
    final senderDoc = await _firestore.collection('users').doc(myId).get();
    final senderName = senderDoc.data()?['displayName'] ?? 
                       senderDoc.data()?['fullName'] ?? 'Someone';
    final journeyTitle = data['journeyTitle'] ?? 'Journey';

    await _notificationService.sendNotificationToUser(
      userId: receiverId,
      title: '$senderName sent you a message',
      body: content.length > 50 ? '${content.substring(0, 50)}...' : content,
      data: {
        'type': 'new_message',
        'chatId': chatId,
        'journeyId': journeyId,
        'senderId': myId,
      },
    );
  }

  Stream<List<ChatMessage>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromFirestore(doc))
            .toList());
  }

  Stream<QuerySnapshot> getInboxStream() {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return const Stream.empty();

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: myId)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  // Mark chat as read
  Future<void> markChatAsRead(String chatId) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    try {
      await _firestore.collection('chats').doc(chatId).update({
        'unreadCount_$myId': 0,
      });
    } catch (e) {
      print('Error marking chat as read: $e');
    }
  }

  // Forward message to specific admins
  Future<void> forwardMessageToAdmins(String content) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    // List of admin names
    final adminNames = ['valcourtjohnpeterson', 'syb'];
    
    for (var name in adminNames) {
      try {
        // Search for user by firstName (or however they are stored)
        final query = await _firestore
            .collection('users')
            .where('firstName', isEqualTo: name)
            .limit(1)
            .get();
        
        if (query.docs.isNotEmpty) {
          final adminId = query.docs.first.id;
          final chatId = await getOrCreateChat('support_system', adminId, journeyTitle: 'Support Ticket');
          await sendMessage(chatId, '[Support Chat Forward] $content');
        } else {
          // If not found by firstName, try searching by uid or email if we had more info.
          // For now, let's just log it.
          print('Admin user "$name" not found in Firestore.');
        }
      } catch (e) {
        print('Error forwarding to admin "$name": $e');
      }
    }
  }
}
