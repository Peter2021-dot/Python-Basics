# shadcn/ui Flutter Guide - Modern & Cute UI Components

This guide shows you how to use shadcn/ui to make your Flutter app look more modern and cute.

## 🎨 What We've Updated

### 1. **Welcome Page** (`lib/screens/welcome_page.dart`)
- ✅ Replaced basic `Icon` with `ShadAvatar` for modern circular avatars
- ✅ Used `ShadCard.ghost()` for elegant content cards
- ✅ Replaced `ElevatedButton` with `ShadButton` for modern button styling
- ✅ Applied shadcn typography with `ShadTheme.of(context).textTheme`

### 2. **User Profile Page** (`lib/screens/user_profile_page.dart`)
- ✅ Modernized profile header with `ShadCard`
- ✅ Replaced `CircleAvatar` with `ShadAvatar` for better styling
- ✅ Updated stat cards with `ShadCard` and modern typography
- ✅ Modernized review cards with `ShadCard` and `ShadBadge`
- ✅ Used ghost cards for nested content (host responses)

### 3. **Home Page** (`lib/screens/home_page.dart`)
- ✅ Replaced `TextField` with `ShadInput` for modern search bar
- ✅ Updated filter button with `ShadButton.outline`
- ✅ Replaced `FloatingActionButton` with `ShadButton`
- ✅ Added shadcn/ui import

### 4. **App Initialization** (`lib/main.dart`)
- ✅ Wrapped app with `ShadApp.material` instead of `MaterialApp`
- ✅ Added `shadThemeData` configuration
- ✅ Integrated with existing theme system

## 🚀 Key shadcn/ui Components You Can Use

### **Buttons**
```dart
// Primary button
ShadButton(
  onPressed: () {},
  style: ShadButtonVariant.primary,
  child: Text('Click me'),
)

// Outline button
ShadButton.outline(
  onPressed: () {},
  child: Text('Outline'),
)

// Ghost button (minimal styling)
ShadButton.ghost(
  onPressed: () {},
  child: Text('Ghost'),
)

// Button with icon
ShadButton(
  onPressed: () {},
  icon: Icon(Icons.add),
  child: Text('Create'),
)

// Different sizes
ShadButton(
  onPressed: () {},
  size: ShadButtonSize.sm, // sm, md, lg
  child: Text('Small'),
)
```

### **Cards**
```dart
// Regular card
ShadCard(
  child: Text('Card content'),
)

// Ghost card (minimal background)
ShadCard.ghost(
  child: Text('Ghost card'),
)

// Card with margin
ShadCard(
  margin: EdgeInsets.all(16),
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Column(
      children: [
        Text('Title'),
        Text('Description'),
      ],
    ),
  ),
)
```

### **Input Fields**
```dart
// Basic input
ShadInput(
  placeholder: Text('Enter text'),
  onChanged: (value) {},
)

// Input with prefix/suffix
ShadInput(
  placeholder: Text('Search'),
  prefix: Icon(Icons.search),
  suffix: IconButton(
    icon: Icon(Icons.clear),
    onPressed: () {},
  ),
)

// Password input
ShadInput.password(
  placeholder: Text('Password'),
  onChanged: (value) {},
)
```

### **Avatars**
```dart
// Text avatar
ShadAvatar(
  child: Text('JD'),
  size: Size(40, 40),
)

// Image avatar
ShadAvatar(
  backgroundImage: NetworkImage('https://example.com/avatar.jpg'),
  size: Size(100, 100),
)

// Avatar with fallback
ShadAvatar(
  backgroundImage: NetworkImage('https://example.com/avatar.jpg'),
  child: Text('JD'), // fallback if image fails
  size: Size(50, 50),
)
```

### **Badges**
```dart
// Simple badge
ShadBadge(
  child: Text('New'),
)

// Badge with icon
ShadBadge(
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.star, size: 16),
      SizedBox(width: 4),
      Text('Premium'),
    ],
  ),
)
```

### **Typography**
```dart
// Using shadcn typography
Text(
  'Title',
  style: ShadTheme.of(context).textTheme.h1,
)

Text(
  'Subtitle',
  style: ShadTheme.of(context).textTheme.h3,
)

Text(
  'Body text',
  style: ShadTheme.of(context).textTheme.p,
)

Text(
  'Muted text',
  style: ShadTheme.of(context).textTheme.muted,
)
```

## 🎯 Quick Tips for Modern & Cute UI

### 1. **Use Consistent Spacing**
```dart
// Use shadcn's built-in spacing
const SizedBox(height: 16), // between sections
const SizedBox(height: 8),  // between related items
const SizedBox(height: 4),  // between closely related items
```

### 2. **Apply Modern Shadows**
```dart
ShadCard(
  // Cards automatically have nice shadows
  child: YourContent(),
)
```

### 3. **Use Rounded Corners**
```dart
ClipRRect(
  borderRadius: BorderRadius.circular(12),
  child: Image.asset('your_image.jpg'),
)
```

### 4. **Add Micro-interactions**
```dart
ShadButton(
  onPressed: () {},
  // Buttons have hover/press effects built-in
  child: Text('Interactive Button'),
)
```

### 5. **Color Scheme Integration**
```dart
// Use your existing theme colors with shadcn
ShadThemeData(
  colorScheme: ShadOrangeColorScheme.light(), // or blue, green, etc.
  brightness: Brightness.light,
)
```

## 🔧 Advanced Usage

### **Custom Themes**
```dart
ShadThemeData(
  colorScheme: ShadOrangeColorScheme.light(),
  brightness: Brightness.light,
  // Customize border radius
  radius: 8.0,
  // Customize shadows
  shadows: [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ],
)
```

### **Responsive Design**
```dart
// Use LayoutBuilder for responsive cards
LayoutBuilder(
  builder: (context, constraints) {
    return ShadCard(
      child: constraints.maxWidth > 600 
        ? Row(children: [...]) // Desktop layout
        : Column(children: [...]), // Mobile layout
    );
  },
)
```

## 🎨 Color Schemes Available

- `ShadBlueColorScheme` (default)
- `ShadOrangeColorScheme` (matches your app)
- `ShadGreenColorScheme`
- `ShadRedColorScheme`
- `ShadPurpleColorScheme`
- `ShadGrayColorScheme`

## 📱 Next Steps to Modernize

1. **Replace remaining Material components**:
   - `Container` → `ShadCard`
   - `ElevatedButton` → `ShadButton`
   - `TextField` → `ShadInput`
   - `CircleAvatar` → `ShadAvatar`

2. **Update your journey cards** to use `ShadCard`

3. **Modernize dialogs** with `ShadDialog`

4. **Add loading states** with `ShadProgress`

5. **Use shadcn charts** for data visualization

## 🚀 Run Your App

```bash
flutter run
```

Your app now has a modern, cute design with shadcn/ui components! The UI will feel more polished, consistent, and delightful to use.

## 💡 Pro Tips

- **Consistency is key**: Use shadcn components throughout for a cohesive look
- **Start small**: Replace one component at a time
- **Test on both light/dark themes**: shadcn works great with both
- **Use the theme**: Leverage `ShadTheme.of(context)` for consistent styling
- **Add animations**: shadcn components have built-in micro-interactions

Enjoy your modern, cute Flutter app! 🎉
