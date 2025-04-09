import 'package:flutter/material.dart';
import '../common/custom_dropdown.dart';

class CameraSection extends StatelessWidget {
  final int selectedCamera;
  final ValueChanged<int?> onCameraChanged;

  const CameraSection({
    super.key,
    required this.selectedCamera,
    required this.onCameraChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Camera Selection',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        CustomDropdown<int>(
          value: selectedCamera,
          items: List.generate(4, (index) => index + 1),
          onChanged: onCameraChanged,
          label: 'Camera',
        ),
      ],
    );
  }
}
