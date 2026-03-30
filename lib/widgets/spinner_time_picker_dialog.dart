import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_time_picker_spinner/flutter_time_picker_spinner.dart';

String _formatTimeOfDay(TimeOfDay value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

Future<TimeOfDay?> showSpinnerTimePickerDialog({
  required BuildContext context,
  required TimeOfDay initialTime,
  String title = 'Select time',
}) async {
  TimeOfDay selected = initialTime;

  return showDialog<TimeOfDay>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      final maxDialogHeight = MediaQuery.of(dialogContext).size.height * 0.65;

      return StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(title),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 420,
              maxHeight: maxDialogHeight,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Heure'),
                    subtitle: Text(_formatTimeOfDay(selected)),
                    trailing: const Icon(Icons.access_time),
                  ),
                  SizedBox(
                    height: 220,
                    child: ScrollConfiguration(
                      behavior: const MaterialScrollBehavior().copyWith(
                        dragDevices: {
                          PointerDeviceKind.touch,
                          PointerDeviceKind.mouse,
                          PointerDeviceKind.stylus,
                          PointerDeviceKind.trackpad,
                          PointerDeviceKind.unknown,
                        },
                      ),
                      child: TimePickerSpinner(
                        is24HourMode: true,
                        isShowSeconds: false,
                        minutesInterval: 1,
                        time: DateTime(
                          2000,
                          1,
                          1,
                          selected.hour,
                          selected.minute,
                        ),
                        onTimeChange: (dateTime) {
                          setState(() {
                            selected = TimeOfDay(
                              hour: dateTime.hour,
                              minute: dateTime.minute,
                            );
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(selected),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    },
  );
}
