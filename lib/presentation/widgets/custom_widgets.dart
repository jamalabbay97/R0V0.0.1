import 'package:flutter/material.dart';
import 'package:r0/presentation/theme.dart';

// --- Cards ---

class OCPCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;

  const OCPCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
          child: child,
        ),
      ),
    );
  }
}

class OCPInfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? iconColor;

  const OCPInfoCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return OCPCard(
      child: Row(
        children: [
          Container(
            width: AppSizes.iconBox,
            height: AppSizes.iconBox,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (iconColor ?? Theme.of(context).primaryColor)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.control),
              border: Border.all(
                color: (iconColor ?? Theme.of(context).primaryColor)
                    .withValues(alpha: 0.2),
              ),
            ),
            child: Icon(
              icon,
              color: iconColor ?? Theme.of(context).primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Buttons ---

class OCPButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool isSecondary;
  final bool isDestructive;

  const OCPButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.isSecondary = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine style based on destructive/secondary flags
    ButtonStyle style;
    if (isSecondary) {
      style = ButtonStyles.secondaryButton(context);
    } else if (isDestructive) {
      style = ButtonStyles.dangerButton(context);
    } else {
      style = ButtonStyles.primaryButton(context);
    }

    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: isSecondary ? theme.primaryColor : Colors.white,
            ),
          ),
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          Icon(icon, size: 20),
          const SizedBox(width: 8),
        ],
        Text(text),
      ],
    );

    if (isSecondary) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: style,
        child: content,
      );
    } else {
      return ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: style,
        child: content,
      );
    }
  }
}

// --- Inputs ---

class OCPTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool readOnly;

  const OCPTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.obscureText = false,
    this.suffixIcon,
    this.onChanged,
    this.enabled = true,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          obscureText: obscureText,
          onChanged: onChanged,
          enabled: enabled,
          readOnly: readOnly,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

class OCPDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? Function(T?)? validator;

  const OCPDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          key: ValueKey(value),
          initialValue: value,
          items: items,
          onChanged: onChanged,
          validator: validator,
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
      ],
    );
  }
}

// --- Stepper ---

class OCPStepper extends StatelessWidget {
  final List<String> steps;
  final int currentStep;
  final ValueChanged<int>? onStepTapped;

  const OCPStepper({
    super.key,
    required this.steps,
    required this.currentStep,
    this.onStepTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: steps.length,
        itemBuilder: (context, index) {
          final isCompleted = index < currentStep;
          final isCurrent = index == currentStep;

          return GestureDetector(
            onTap: onStepTapped != null ? () => onStepTapped!(index) : null,
            child: Container(
              margin: const EdgeInsets.only(right: AppSpacing.xs),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color:
                    isCurrent ? AppColors.primary : Theme.of(context).cardColor,
                border: Border.all(
                  color: isCompleted || isCurrent
                      ? AppColors.primary
                      : Theme.of(context).dividerColor,
                  width: 1.2,
                ),
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isCompleted)
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 20,
                      color: AppColors.primaryHover,
                    )
                  else
                    Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: isCurrent ? Colors.white : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    steps[index],
                    style: TextStyle(
                      color: isCurrent
                          ? Colors.white
                          : (isCompleted
                              ? AppColors.primaryHover
                              : Theme.of(context).textTheme.bodySmall?.color),
                      fontWeight: isCurrent || isCompleted
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
