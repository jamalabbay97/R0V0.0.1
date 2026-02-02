# OCP Reports Mobile App - UI Design Specification

## Overview
Modern, professional Android mobile application for creating and managing industrial operational reports for OCP Group (Morocco). Optimized for field engineers and supervisors in mining and industrial environments.

---

## Design System

### Color Palette

#### Light Mode
- **Primary Green**: `#2E7D32` (OCP Brand)
- **Secondary Green**: `#4CAF50` (Accents)
- **Background**: `#F9FAF9` (Neutral light gray)
- **Card Background**: `#FFFFFF` (Pure white)
- **Text Primary**: `#212121` (Dark gray)
- **Text Secondary**: `#757575` (Medium gray)
- **Divider**: `#E0E0E0`

#### Dark Mode
- **Primary Green**: `#2E7D32` (Same)
- **Secondary Green**: `#4CAF50` (Same)
- **Background**: `#121212` (Material dark)
- **Card Background**: `#1E1E1E` (Elevated surface)
- **Text Primary**: `#FFFFFF` (White)
- **Text Secondary**: `#B0B0B0` (Light gray)
- **Divider**: `#2C2C2C`

### Typography
- **Headline Large**: 32sp, Bold, OCP Green or White (dark mode)
- **Headline Medium**: 24sp, Bold, Primary text color
- **Title Large**: 22sp, SemiBold
- **Title Medium**: 18sp, SemiBold
- **Body Large**: 16sp, Regular
- **Body Medium**: 14sp, Regular
- **Caption**: 12sp, Regular, Secondary text color

### Spacing System
- **XS**: 4dp
- **S**: 8dp
- **M**: 16dp
- **L**: 24dp
- **XL**: 32dp

### Elevation & Shadow
- **Cards**: 2dp elevation, subtle shadow
- **Buttons**: No elevation (flat), 1dp on press
- **Dialogs**: 8dp elevation

### Border Radius
- **Cards**: 16dp
- **Buttons**: 12dp
- **Input Fields**: 8dp
- **Chips**: 20dp

---

## Screen Designs

### 1. Home Dashboard

#### Layout Structure
```
┌─────────────────────────────┐
│  [OCP Logo] OCP Reports     │ ← Header (68dp height)
├─────────────────────────────┤
│                             │
│  ┌──────────┐  ┌──────────┐ │
│  │ R0       │  │ Activity │ │ ← Report Cards Grid
│  │ Report   │  │ Report   │ │   (2 columns)
│  └──────────┘  └──────────┘ │
│                             │
│  ┌──────────┐  ┌──────────┐ │
│  │ Daily    │  │ Truck    │ │
│  │ Report   │  │ Tracking │ │
│  └──────────┘  └──────────┘ │
│                             │
│  ┌──────────┐  ┌──────────┐ │
│  │ Machines │  │ Reports  │ │
│  │ Stopped  │  │ Archive  │ │
│  └──────────┘  └──────────┘ │
│                             │
└─────────────────────────────┘
```

#### Header
- **Height**: 68dp
- **Background**: Card background color
- **Content**:
  - OCP Logo (circular, 40dp, left-aligned, 16dp margin)
  - "OCP Reports" title (Title Large, left of logo)
- **Shadow**: 1dp bottom shadow

#### Report Cards
- **Size**: Flexible width (2 columns with 16dp gap), 140dp height
- **Padding**: 16dp
- **Background**: Card background
- **Border Radius**: 16dp
- **Shadow**: 2dp elevation
- **Content**:
  - Icon (top-left, 32dp, Primary green)
  - Title (Body Large, SemiBold, 8dp below icon)
  - Description (Caption, Secondary text, 4dp below title)
- **Hover/Press**: Scale 0.98, slight shadow increase

### 2. Report Creation Flow (Stepper)

#### Horizontal Stepper
```
┌─────────────────────────────┐
│  ①──②──③──④──⑤──⑥          │ ← Stepper (Numbers only)
│  ✓  ✓  ●  ○  ○  ○          │   Completed = ✓, Active = ●, Inactive = ○
└─────────────────────────────┘
```

- **Height**: 64dp
- **Step Circles**: 32dp diameter
- **Line Thickness**: 2dp
- **Spacing**: Equal distribution
- **Colors**:
  - Completed: Primary green circle, white checkmark
  - Active: Primary green circle, white number
  - Inactive: Light gray circle, gray number
  - Connecting line: Green (completed), Gray (inactive)

#### Content Area
```
┌─────────────────────────────┐
│  ÉTAPE 3: ARRÊTS           │ ← Page Title (Headline Medium)
│                             │
│  ┌─────────────────────┐   │
│  │                     │   │
│  │  [Form Content]     │   │ ← White card with content
│  │                     │   │
│  └─────────────────────┘   │
│                             │
│  ┌─────────────────────┐   │
│  │   [Previous]        │   │ ← Navigation buttons
│  └─────────────────────┘   │
│  ┌─────────────────────┐   │
│  │   [Next/Submit]     │   │
│  └─────────────────────┘   │
└─────────────────────────────┘
```

- **Page Title**: 
  - Headline Medium, Bold
  - Primary green color
  - 24dp top margin, 16dp bottom margin
  
- **Content Cards**:
  - White background (light) / Elevated dark (dark mode)
  - 16dp padding
  - 16dp border radius
  - Margin: 16dp horizontal

### 3. Buttons

#### Primary Button (Submit, Next, Add)
- **Height**: 48dp
- **Background**: Primary green `#2E7D32`
- **Text**: White, Body Large, SemiBold
- **Border Radius**: 12dp
- **Icon**: 24dp, left-aligned with 8dp text spacing
- **Padding**: 16dp horizontal
- **Full-width**: Yes (with 16dp screen margins)
- **Press State**: Darken by 10%

#### Secondary Button (Previous, Cancel, View)
- **Height**: 48dp
- **Background**: Transparent
- **Border**: 2dp solid Primary green
- **Text**: Primary green, Body Large, SemiBold
- **Border Radius**: 12dp
- **Padding**: 16dp horizontal
- **Press State**: Light green background `#E8F5E9`

### 4. Form Elements

#### Text Input
```
┌─────────────────────────────┐
│ Label Text                  │ ← Caption, Secondary color
│ ┌─────────────────────────┐ │
│ │ Input value here        │ │ ← Body Large, 48dp height
│ └─────────────────────────┘ │
│ Helper text or error        │ ← Caption, Secondary/Error color
└─────────────────────────────┘
```

- **Height**: 48dp
- **Border**: 1dp, `#E0E0E0` (light) / `#2C2C2C` (dark)
- **Border Radius**: 8dp
- **Padding**: 12dp horizontal
- **Focus**: Border becomes Primary green, 2dp width
- **Error**: Border becomes red `#D32F2F`

#### Dropdown
- Same as Text Input
- Right-aligned dropdown arrow icon (16dp)
- Popup menu: Card background, 8dp elevation

#### Duration Picker
- Clock icon (left, 24dp)
- Format: `Xh XXm`
- Tappable to open time picker dialog

### 5. Data Display Cards

#### Summary Card
```
┌─────────────────────────────┐
│  Section Title              │ ← Title Medium, SemiBold
│  ─────────────────────────  │ ← Divider
│  Label:        Value        │ ← Body Medium
│  Label:        Value        │
│  Label:        Value        │
└─────────────────────────────┘
```

- **Background**: Card background
- **Padding**: 16dp
- **Border Radius**: 16dp
- **Row Height**: 32dp
- **Label**: Secondary text
- **Value**: Primary text, SemiBold

### 6. Verification Screen

#### Layout
```
┌─────────────────────────────┐
│  ①──②──③──④──⑤──⑥          │
│  ✓  ✓  ✓  ✓  ✓  ✓          │ ← All completed
├─────────────────────────────┤
│  ÉTAPE 6: VÉRIFICATION      │
│                             │
│  ┌─────────────────────┐   │
│  │ Résumé des données  │   │
│  │ ─────────────────── │   │
│  │ Date: 21/01/2026    │   │
│  │ Équipements: 3      │   │
│  │ Total Arrêts: 5h45m │   │
│  │ Stock ajouté: Oui   │   │
│  └─────────────────────┘   │
│                             │
│  ┌─────────────────────┐   │
│  │ 👁 View All Details  │   │ ← Outlined button
│  └─────────────────────┘   │
│                             │
│  ┌─────────────────────┐   │
│  │ SUBMIT REPORT       │   │ ← Primary button
│  └─────────────────────┘   │
│                             │
│  📶 Changes will sync when  │ ← Offline indicator
│     online                  │
└─────────────────────────────┘
```

### 7. Success Confirmation

#### Layout
```
┌─────────────────────────────┐
│                             │
│                             │
│         ┌─────────┐         │
│         │    ✓    │         │ ← Large green checkmark
│         └─────────┘         │
│                             │
│  Report Submitted           │ ← Headline Medium
│  Successfully               │
│                             │
│  Report #R0-2026-001        │ ← Body Medium, Secondary
│  has been saved             │
│                             │
│  ┌─────────────────────┐   │
│  │ Date: 21/01/2026    │   │ ← Summary card
│  │ Type: R0 Report     │   │
│  │ Equipment: 3        │   │
│  └─────────────────────┘   │
│                             │
│  ┌─────────────────────┐   │
│  │ RETURN TO HOME      │   │ ← Primary button
│  └─────────────────────┘   │
│                             │
└─────────────────────────────┘
```

- **Checkmark Circle**: 
  - 120dp diameter
  - Primary green background
  - White checkmark icon (64dp)
  - Subtle scale animation on appear

---

## Mobile Optimization

### Touch Targets
- **Minimum**: 48dp × 48dp
- **Recommended**: 56dp × 56dp for primary actions
- **Spacing**: 8dp between adjacent touch targets

### One-Hand Operation
- **Bottom Navigation**: Primary actions at bottom
- **Thumb Zone**: Important buttons within 200-300dp from bottom
- **Scroll**: All content scrollable, no fixed heights requiring reach

### Outdoor Visibility
- **Contrast Ratio**: Minimum 4.5:1 for body text
- **Text Size**: Minimum 14sp for important content
- **Colors**: High saturation primary green for visibility
- **Dark Mode**: Essential for battery and low-light conditions

### Performance
- **Animations**: Maximum 300ms duration
- **Feedback**: Immediate visual response (<100ms)
- **Loading States**: Skeleton screens or shimmer effects

---

## Component Library

### ReusableCard
```kotlin
Card(
    modifier = Modifier
        .fillMaxWidth()
        .padding(horizontal = 16.dp),
    shape = RoundedCornerShape(16.dp),
    elevation = CardDefaults.cardElevation(2.dp),
    colors = CardDefaults.cardColors(
        containerColor = MaterialTheme.colorScheme.surface
    )
) {
    // Content
}
```

### PrimaryButton
```kotlin
Button(
    onClick = { },
    modifier = Modifier
        .fillMaxWidth()
        .height(48.dp)
        .padding(horizontal = 16.dp),
    shape = RoundedCornerShape(12.dp),
    colors = ButtonDefaults.buttonColors(
        containerColor = Color(0xFF2E7D32)
    )
) {
    Text("Button Text", style = MaterialTheme.typography.bodyLarge)
}
```

### StepIndicator
```kotlin
Row(
    modifier = Modifier.fillMaxWidth(),
    horizontalArrangement = Arrangement.SpaceEvenly
) {
    steps.forEachIndexed { index, step ->
        StepCircle(
            stepNumber = index + 1,
            isCompleted = index < currentStep,
            isActive = index == currentStep
        )
        if (index < steps.size - 1) {
            StepLine(isCompleted = index < currentStep)
        }
    }
}
```

---

## Accessibility

### Screen Reader Support
- All interactive elements have content descriptions
- Headings marked with semantic roles
- Navigation announces current step

### Text Scaling
- Support for 200% text scaling
- Layout responsive to text size changes

### Color Blindness
- Not relying solely on color for status
- Icons and text labels for all states
- High contrast mode compatible

---

## Implementation Notes

### Material Design 3
- Use Material You color system
- Dynamic color not required (fixed OCP brand colors)
- Component tokens for consistency

### Jetpack Compose
- All designs translate directly to Compose
- Use Modifier chains for styling
- State Management: ViewModel pattern

### Offline Support
- Visual indicators when offline
- Queue actions for later sync
- Clear feedback on sync status

---

## Asset Export Requirements

### Icons
- **Size**: 24dp (standard), 32dp (large)
- **Format**: Vector (XML)
- **Color**: Tintable (single color)

### Logos
- **OCP Logo**: Vector, 40dp square
- **Format**: PNG + Vector

### Illustrations
- **Success States**: Vector illustrations
- **Empty States**: Simple, on-brand illustrations

---

## Figma/Design Tool Setup

### Artboards
- **Size**: 360 × 800dp (standard Android phone)
- **Safe Area**: 16dp margins on all sides

### Grid System
- **Columns**: 4 (mobile)
- **Gutter**: 16dp
- **Margin**: 16dp

### Component Variants
- Light mode / Dark mode
- Normal / Error states
- Empty / Filled states

---

## Next Steps

1. Create Figma/Adobe XD prototype with these specifications
2. Build component library in Jetpack Compose
3. Implement dark mode theme switching
4. Test outdoor visibility in field conditions
5. Usability testing with actual field engineers

---

**Version**: 1.0  
**Date**: January 21, 2026  
**Designer**: Antigravity AI  
**Client**: OCP Group, Morocco
