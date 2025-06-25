import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:pdfx/pdfx.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

class ChatpdfPage extends StatefulWidget {
  @override
  _ChatpdfPageState createState() => _ChatpdfPageState();
}

class _ChatpdfPageState extends State<ChatpdfPage> {
  PlatformFile? _selectedFile;
  String? _analysisResult;
  bool _isAnalyzing = false;
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();

  // Initialize Gemini AI
  final _geminiModel = GenerativeModel(
    model: 'gemini-1.5-flash-latest', // Corrected model name
    apiKey: 'AIzaSyBnwtYHw5NBa03bcyXZL9KxBulZcF3MaGE', // Replace with your secure API key
    generationConfig: GenerationConfig(
      maxOutputTokens: 1000, // Limit output for efficiency
      temperature: 0.7, // Balance creativity and accuracy
    ),
  );

  // Function to handle file picking
  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'ppt'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = result.files.single;
          _analysisResult = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File ${_selectedFile!.name} selected successfully!')),
        );
        await _analyzeFile(_selectedFile!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No file selected.')),
        );
      }
    } catch (e) {
      print('Error picking file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  // Function to extract text from a PDF file using pdfx and OCR
  Future<String> _extractTextFromPdf(String filePath) async {
    try {
      setState(() {
        _isAnalyzing = true;
      });
      final doc = await PdfDocument.openFile(filePath);
      String text = '';
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      for (var i = 1; i <= doc.pagesCount; i++) {
        final page = await doc.getPage(i);
        // Render page to image for OCR with optimized resolution
        final image = await page.render(
          width: page.width * 2, // Increase resolution for better OCR
          height: page.height * 2,
          format: PdfPageImageFormat.png,
        );
        final imageFile = File('${filePath}-page-$i.png');
        await imageFile.writeAsBytes(image!.bytes);
        final inputImage = InputImage.fromFilePath(imageFile.path);
        final recognizedText = await textRecognizer.processImage(inputImage);
        if (recognizedText.text.isNotEmpty) {
          text += 'Page $i:\n${recognizedText.text}\n';
        }
        await imageFile.delete();
        await page.close();
      }
      await textRecognizer.close();
      await doc.close();
      setState(() {
        _isAnalyzing = false;
      });
      return text.isNotEmpty ? text : 'No text found in the PDF. Ensure the document contains readable content.';
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
      });
      throw Exception('Error extracting text from PDF: $e');
    }
  }

  // Function to download and extract text from a PDF URL
  Future<String> _extractTextFromPdfUrl(String url) async {
    try {
      setState(() {
        _isAnalyzing = true;
      });
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final tempDir = await Directory.systemTemp.createTemp();
        final tempFile = File('${tempDir.path}/${path.basename(url)}');
        await tempFile.writeAsBytes(response.bodyBytes);
        final text = await _extractTextFromPdf(tempFile.path);
        await tempFile.delete();
        return text;
      } else {
        throw Exception('Failed to download PDF: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
      });
      throw Exception('Error processing PDF URL: $e');
    }
  }

  // Function to analyze file using Gemini AI
  Future<void> _analyzeFile(PlatformFile file) async {
    try {
      setState(() {
        _analysisResult = 'Extracting text and analyzing file...';
        _isAnalyzing = true;
      });

      String extractedText;
      if (file.path != null) {
        if (file.name.endsWith('.pdf')) {
          extractedText = await _extractTextFromPdf(file.path!);
        } else {
          extractedText = 'Text extraction for ${file.name} (DOC/PPT) not implemented.';
        }
      } else {
        extractedText = await _extractTextFromPdfUrl(file.name);
      }

      // Truncate text if too long to avoid Gemini token limits
      if (extractedText.length > 5000) {
        extractedText = extractedText.substring(0, 5000) + '\n[Truncated due to length]';
      }

      // Analyze with Gemini AI using a detailed prompt
      final prompt = '''
Analyze the following document content and provide a concise summary (100-200 words) that captures the main topics, key points, and purpose of the document. If the content is limited or unclear, note the limitations and provide the best possible summary based on available information.

Document content:
$extractedText
''';
      final response = await _geminiModel.generateContent([Content.text(prompt)]);
      setState(() {
        _analysisResult = 'AI Analysis for ${file.name}:\n${response.text ?? "No analysis provided by AI."}';
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _analysisResult = 'Error analyzing file: $e';
        _isAnalyzing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error analyzing file: $e')),
      );
    }
  }

  // Function to handle question submission
  Future<void> _submitQuestion() async {
    String question = _questionController.text.trim();
    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pertanyaan tidak boleh kosong!')),
      );
      return;
    }
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Silakan unggah file terlebih dahulu!')),
      );
      return;
    }
    try {
      setState(() {
        _analysisResult = 'Processing question...';
        _isAnalyzing = true;
      });
      String extractedText;
      if (_selectedFile!.path != null) {
        extractedText = await _extractTextFromPdf(_selectedFile!.path!);
      } else {
        extractedText = await _extractTextFromPdfUrl(_selectedFile!.name);
      }

      // Truncate text if too long
      if (extractedText.length > 5000) {
        extractedText = extractedText.substring(0, 5000) + '\n[Truncated due to length]';
      }

      // Detailed prompt for question answering
      final prompt = '''
You are an expert assistant analyzing a document. Based on the document content below, provide a precise and accurate answer to the user's question. If the answer is not explicitly in the document, infer a reasonable response based on the context or state that the information is not available. Keep the answer concise (50-150 words).

Document content:
$extractedText

User's question:
$question
''';
      final response = await _geminiModel.generateContent([Content.text(prompt)]);
      setState(() {
        _analysisResult = 'Question: $question\nAnswer: ${response.text ?? "No answer provided by AI."}';
        _isAnalyzing = false;
      });
      _questionController.clear();
    } catch (e) {
      setState(() {
        _analysisResult = 'Error answering question: $e';
        _isAnalyzing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error answering question: $e')),
      );
    }
  }

  // Function to handle PDF link input
  Future<void> _inputPdfLink() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Masukkan Tautan PDF'),
          content: TextField(
            controller: _linkController,
            decoration: InputDecoration(
              hintText: 'https://example.com/sample.pdf',
              labelText: 'URL PDF',
            ),
            keyboardType: TextInputType.url,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                String link = _linkController.text.trim();
                if (link.isNotEmpty) {
                  setState(() {
                    _selectedFile = PlatformFile(
                      name: path.basename(link),
                      path: null,
                      size: 0,
                      bytes: null,
                    );
                    _analysisResult = null;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Tautan PDF: $link')),
                  );
                  _analyzeFile(_selectedFile!);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Tautan tidak boleh kosong!')),
                  );
                }
              },
              child: Text('Kirim'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _questionController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.picture_as_pdf, color: Colors.red, size: 40),
                    SizedBox(width: 10),
                    Icon(Icons.description, color: Colors.purple, size: 40),
                    SizedBox(width: 10),
                    Icon(Icons.slideshow, color: Colors.orange, size: 40),
                  ],
                ),
                SizedBox(height: 20),
                Text(
                  'Klik atau seret file ke halaman ini untuk mengunggah atau masukkan tautan PDF',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10),
                Text(
                  'Format: pdf / doc / ppt',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isAnalyzing ? null : _pickFile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.upload),
                      SizedBox(width: 5),
                      Text('Unggah'),
                    ],
                  ),
                ),
                // SizedBox(height: 10),
                // TextButton(
                //   onPressed: _isAnalyzing ? null : _inputPdfLink,
                //   child: Row(
                //     mainAxisSize: MainAxisSize.min,
                //     children: [
                //       Icon(Icons.link, size: 16),
                //       SizedBox(width: 5),
                //       Text('Tautan PDF'),
                //     ],
                //   ),
                // ),
                SizedBox(height: 20),
                if (_selectedFile != null)
                  Card(
                    elevation: 2,
                    child: ListTile(
                      leading: Icon(
                        _selectedFile!.name.endsWith('.pdf')
                            ? Icons.picture_as_pdf
                            : _selectedFile!.name.endsWith('.doc')
                                ? Icons.description
                                : Icons.slideshow,
                        color: _selectedFile!.name.endsWith('.pdf')
                            ? Colors.red
                            : _selectedFile!.name.endsWith('.doc')
                                ? Colors.purple
                                : Colors.orange,
                      ),
                      title: Text(_selectedFile!.name),
                      subtitle: Text(
                        _selectedFile!.size > 0
                            ? 'Size: ${(_selectedFile!.size / 1024).toStringAsFixed(2)} KB'
                            : 'Link-based file',
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.close),
                        onPressed: _isAnalyzing
                            ? null
                            : () {
                                setState(() {
                                  _selectedFile = null;
                                  _analysisResult = null;
                                });
                              },
                      ),
                    ),
                  ),
                SizedBox(height: 20),
                if (_analysisResult != null)
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hasil Analisis AI',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 10),
                          Text(_analysisResult!),
                        ],
                      ),
                    ),
                  ),
                SizedBox(height: 20),
                if (_selectedFile != null)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _questionController,
                          decoration: InputDecoration(
                            labelText: 'Tanyakan sesuatu tentang file',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.text,
                          maxLines: 2,
                          enabled: !_isAnalyzing,
                        ),
                      ),
                      SizedBox(width: 10),
                      IconButton(
                        icon: Icon(Icons.send),
                        color: Colors.black,
                        onPressed: _isAnalyzing ? null : _submitQuestion,
                      ),
                    ],
                  ),
                SizedBox(height: 20), // Extra padding at bottom
              ],
            ),
          ),
          if (_isAnalyzing)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}