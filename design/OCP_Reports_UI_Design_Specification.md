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
