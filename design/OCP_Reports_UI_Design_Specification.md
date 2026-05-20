<<<<<<< ours
# OCP Reports System - Enterprise Dark UI Redesign

## Direction

OCP Reports should feel like a serious operational control surface for mining and logistics teams: quiet, precise, compact, and readable during long shifts. The product keeps the OCP dark identity and uses green as a confident operational accent, not decoration.

The design language is influenced by Linear, Notion dark UI, IBM Carbon, Tesla-style internal dashboards, enterprise analytics tools, and modern SCADA systems. The result should be restrained: strong alignment, consistent components, low visual noise, subtle borders, and clear status communication.

## Color System

### Dark Mode
- Primary background: `#0B0F0C`
- Secondary surface: `#121715`
- Card surface: `#161C19`
- Elevated modal: `#1A211D`
- Border: `#29332D`
- OCP green: `#3BAA35`
- Hover green: `#4BC545`
- Success: `#3BAA35`
- Warning: `#C98A2E`
- Error: `#E5484D`
- Primary text: `#F5F7F6`
- Secondary text: `#B7C0BA`
- Muted text: `#7D8781`

### Usage Rules
- Use green for primary actions, active navigation, completed workflow states, and positive operational status.
- Use amber only for warning states requiring review.
- Use red only for destructive actions, critical downtime, failed sync, or invalid data.
- Avoid decorative gradients. If a gradient is required, keep it subtle and surface-based.
- Prefer 1px borders over shadows. Shadows should not be the main depth system.

## Spacing System

Use only the 8pt-compatible spacing scale:

- `4` micro alignment
- `8` tight component spacing
- `12` compact inline spacing
- `16` default screen/list spacing
- `24` card/modal padding
- `32` large section separation
- `40` expanded tablet separation
- `48` major layout spacing

Rules:
- Page horizontal padding: `16` mobile, `24` tablet.
- Card internal padding: `24` default, `18` allowed on compact tablet/mobile forms when space is tight.
- Grid gaps: `16`.
- Section gaps: `24` or `32`.
- Inline icon/text gaps: `8`.

## Radii And Surfaces

- Cards: `18px`
- Buttons: `14px`
- Inputs/selects: `14px`
- Chips/pills: fully rounded
- Modal sheets/dialogs: `18px` or `24px` top sheet radius

Cards use `#161C19`, 1px border, no heavy shadow. Modals use `#1A211D`, clear section spacing, and sticky actions when content scrolls.

## Typography

Use Noto Sans consistently.

- Page title: 24-28, semibold/bold
- Section title: 16-18, semibold
- Card title: 15-16, semibold
- Body: 14-16, regular
- Metadata: 12-13, regular/medium
- Numeric operational data: 14-20, medium/semibold

Avoid oversized type inside cards, forms, filters, and dense dashboards. Information density matters more than marketing-scale display text.

## Components

### Buttons
- Height: `52`
- Radius: `14`
- Primary: filled OCP green, white bold label
- Secondary: transparent, green outline, green label
- Danger: subtle dark red background, soft red border, red-tinted label
- Icon size: `20-22`
- Label weight: semibold/bold
- All buttons in a workflow row must share identical height.

### Inputs And Selects
- Height: `56`
- Radius: `14`
- Background: elevated dark surface
- Border: 1px dark border
- Focus: green border/glow feel through stronger green border
- Labels: secondary text, 14, semibold
- Placeholder: muted, never pure white
- Dropdown icons: right aligned, vertically centered
- Error state: industrial red border plus concise helper text

### Cards
- Radius: `18`
- Padding: `24`
- Border: 1px low-opacity surface border
- No nested card stacks unless representing repeated child records inside a larger data editor
- Use consistent header row: icon container, title/subtitle, optional action

### Chips And Filters
- Use compact rounded chips for module/category filters.
- Active chips: soft green background and green border.
- Filter/search bars in Archive should be sticky and visually grouped on a secondary surface.

### Stepper
- Use a connected horizontal stepper.
- Active: filled green circle.
- Completed: outlined/soft green with check.
- Inactive: muted dark surface with muted label.
- Step labels are short and scannable.
- Same stepper behavior across RO, TSUD, TNB, truck, machine stops, and verification flows.

## Screen Guidance

### Dashboard
- Use a structured grid with equal card proportions.
- Keep card rhythm consistent across all report modules.
- Icon containers are 48x48 with soft green/status tint and border.
- Add subtle operational emphasis through metadata, not decorative graphics.
- Tablet layout can expand to 3-4 columns; mobile remains 2 columns where labels still fit.

### Archive And Report Lists
- Sticky search/filter area.
- Uniform report cards with identical spacing.
- Clear module chips: RO, TSUD, TNB, Suivi Camions, Arrets Machines.
- Rows show type, date/shift, sync/status, author/source, and primary metric.
- Sorting/filter actions should be compact and predictable.

### Tables And Report Data
- Use subtle row separators.
- Align numbers and durations consistently.
- Surface timestamps with secondary text but keep them visible.
- Group data by operation/module before details.
- Avoid cramped multi-line cells where a detail sheet would scan better.

### Timeline
- Use premium segmented operation bars.
- Operation segments: OCP green.
- Downtime: industrial red.
- Use pills for operating/down percentages.
- Keep time markers consistent: 22:30, 06:30, 14:30, 22:30.
- Tap downtime segments to open a detailed bottom sheet.

### Verification
- Split summary into compact statistic cards and detailed grouped sections.
- Reduce empty space by grouping confirmation data into scan-friendly rows.
- Primary submit action remains sticky/low on mobile where possible.
- Warnings and sync status must be visible before submission.

### Modals And Data Editing
- Use centered dialogs on tablet and bottom sheets on phone.
- Title, context subtitle, content sections, sticky actions.
- Keep destructive actions visually separated from primary save actions.
- Preserve entered data and make cancellation explicit for long forms.

## Responsive Behavior

- Mobile: 16px page padding, single-column forms, 2-column dashboard where cards remain legible.
- Tablet: 24px page padding, max content width around 1200, 2-column form sections when it reduces scrolling.
- Touch targets: minimum 48, preferred 52-56 for primary controls.
- Navigation height: 64.
- Do not scale fonts by viewport width.

## Production Recommendations

1. Centralize all new tokens in `lib/presentation/theme.dart`.
2. Use shared OCP components for buttons, cards, fields, dropdowns, steppers, and info rows.
3. Replace hard-coded cards/buttons in report modules gradually with shared components.
4. Audit screens for nested cards, inconsistent red/green usage, and mixed 48/52 button heights.
5. Add golden or screenshot checks for dashboard, archive, timeline, verification, and edit modal states.
6. Test tablet use with gloves/industrial touch behavior by validating 52-56px controls and spacing.
=======
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
>>>>>>> theirs
