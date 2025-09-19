import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class PlantDiagnosisScreen extends StatefulWidget {
  const PlantDiagnosisScreen({super.key});

  @override
  State<PlantDiagnosisScreen> createState() => _PlantDiagnosisScreenState();
}

class _PlantDiagnosisScreenState extends State<PlantDiagnosisScreen> {
  final ImagePicker _picker = ImagePicker();

  File? _capturedImage;
  bool _isUploading = false;
  String? _errorMessage;
  Map<String, dynamic>? _prediction;

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _errorMessage = null;
      _prediction = null;
    });
    try {
      final result = await _picker.pickImage(source: source);
      if (result == null) {
        return;
      }
      setState(() {
        _capturedImage = File(result.path);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Unable to access the selected source. Please try again.';
      });
    }
  }

  Future<void> _uploadImage() async {
    final image = _capturedImage;
    if (image == null) {
      setState(() {
        _errorMessage = 'Please capture or choose a photo first.';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
      _prediction = null;
    });

    try {
      final host = Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';
      final uri = Uri.parse('http://$host:8000/predict?top_k=5&crop_hint=tomato');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('file', image.path));

      final response = await http.Response.fromStream(await request.send());

      if (response.statusCode != 200) {
        throw Exception('Server returned status ${response.statusCode}.');
      }

      final Map<String, dynamic> json = jsonDecode(response.body);
      if (json['prediction'] is! Map<String, dynamic>) {
        throw Exception('Unexpected response format.');
      }

      setState(() {
        _prediction = json['prediction'] as Map<String, dynamic>;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Widget _buildPredictionCard() {
    final prediction = _prediction;
    if (prediction == null) {
      return const SizedBox.shrink();
    }

    final labelRaw = prediction['label_raw']?.toString() ?? 'Unknown';
    final crop = prediction['crop']?.toString() ?? 'Unknown';
    final disease = prediction['disease']?.toString() ?? 'Unknown';
    final confidenceValue = prediction['confidence'];
    final confidence = confidenceValue is num
        ? (confidenceValue * 100).toStringAsFixed(1)
        : 'N/A';

    return Card(
      margin: const EdgeInsets.only(top: 16),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prediction',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            _PredictionRow(title: 'Label', value: labelRaw),
            _PredictionRow(title: 'Crop', value: crop),
            _PredictionRow(title: 'Disease', value: disease),
            _PredictionRow(title: 'Confidence', value: '$confidence%'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plant Diagnosis'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '1. Capture a new photo or choose one from your device.\n'
              '2. Review the preview, then tap "Upload" to send the image to '
              'the local prediction service running on your computer.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_camera),
              label: const Text('Capture Photo'),
              onPressed: _isUploading
                  ? null
                  : () => _pickImage(ImageSource.camera),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_library),
              label: const Text('Choose from Gallery'),
              onPressed: _isUploading
                  ? null
                  : () => _pickImage(ImageSource.gallery),
            ),
            if (_capturedImage != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _capturedImage!,
                  height: 280,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: _isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.cloud_upload),
              label: Text(_isUploading ? 'Uploading...' : 'Upload'),
              onPressed: _isUploading ? null : _uploadImage,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
            _buildPredictionCard(),
            if (Platform.isAndroid)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(
                  'Tip: The Android emulator maps your computer\'s localhost to '
                  'http://10.0.2.2. Ensure the FastAPI server is running on your '
                  'machine so the upload succeeds.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PredictionRow extends StatelessWidget {
  const _PredictionRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
