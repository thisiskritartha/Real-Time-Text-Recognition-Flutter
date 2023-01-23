import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Text Recognition',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late CameraController controller;
  bool isBusy = false;
  late CameraImage img;
  dynamic textRecognition;
  dynamic scannedResult;

  @override
  void initState() {
    super.initState();
    textRecognition = TextRecognizer(script: TextRecognitionScript.latin);

    controller = CameraController(cameras[0], ResolutionPreset.high);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
      controller.startImageStream((image) => {
            if (!isBusy)
              {
                img = image,
                isBusy = true,
                doTextRecognitionOnFrame(),
              }
          });
    });
  }

  @override
  void dispose() {
    controller.dispose();
    textRecognition.close();
    super.dispose();
  }

  doTextRecognitionOnFrame() async {
    final inputImage = getInputImage();
    RecognizedText recognizedText =
        await textRecognition.processImage(inputImage);
    setState(() {
      scannedResult = recognizedText;
      isBusy = false;
    });
  }

  InputImage getInputImage() {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in img.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize = Size(img.width.toDouble(), img.height.toDouble());

    CameraDescription camera = cameras[0];
    final InputImageRotation? imageRotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation);

    final InputImageFormat? inputImageFormat =
        InputImageFormatValue.fromRawValue(img.format.raw);

    final planeData = img.planes.map(
      (Plane plane) {
        return InputImagePlaneMetadata(
          bytesPerRow: plane.bytesPerRow,
          height: plane.height,
          width: plane.width,
        );
      },
    ).toList();

    final inputImageData = InputImageData(
      size: imageSize,
      imageRotation: imageRotation!,
      inputImageFormat: inputImageFormat!,
      planeData: planeData,
    );

    final inputImage =
        InputImage.fromBytes(bytes: bytes, inputImageData: inputImageData);
    return inputImage;
  }

  Widget buildResult() {
    if (scannedResult == null ||
        controller == null ||
        !controller.value.isInitialized) {
      return const Text('');
    }
    final Size imageSize = Size(controller.value.previewSize!.height,
        controller.value.previewSize!.width);
    CustomPainter painter = TextRecognitionPainter(imageSize, scannedResult);
    return CustomPaint(
      painter: painter,
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> stackChildren = [];
    final Size size = MediaQuery.of(context).size;
    stackChildren.add(
      Positioned(
        top: 0,
        left: 0,
        width: size.width,
        height: size.height,
        child: Container(
          child: (controller.value.isInitialized)
              ? CameraPreview(controller)
              : Container(),
        ),
      ),
    );

    stackChildren.add(Positioned(
      top: 0,
      left: 0,
      height: size.height,
      width: size.width,
      child: buildResult(),
    ));

    if (!controller.value.isInitialized) {
      return Container();
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text Recognition'),
        centerTitle: true,
      ),
      body: Container(
        margin: const EdgeInsets.only(top: 0),
        child: Stack(
          children: stackChildren,
        ),
      ),
    );
  }
}

class TextRecognitionPainter extends CustomPainter {
  TextRecognitionPainter(this.absoluteSize, this.recognizedText);
  final Size absoluteSize;
  final RecognizedText recognizedText;
  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / absoluteSize.width;
    final double scaleY = size.height / absoluteSize.height;

    Paint p = Paint();
    p.style = PaintingStyle.stroke;
    p.color = Colors.green;
    p.strokeWidth = 2;

    for (TextBlock block in recognizedText.blocks) {
      final Rect rect = block.boundingBox;
      final List<Point<int>> cornerPoint = block.cornerPoints;
      final String text = block.text;
      final List<String> languages = block.recognizedLanguages;

      canvas.drawRect(
          Rect.fromLTRB(rect.left * scaleX, rect.top * scaleY,
              rect.right * scaleX, rect.bottom * scaleY),
          p);

      TextSpan span = TextSpan(
        text: block.text,
        style: const TextStyle(fontSize: 20, color: Colors.pink),
      );
      TextPainter tp = TextPainter(
          text: span,
          textAlign: TextAlign.left,
          textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(rect.left * scaleX, rect.top * scaleY));
      for (TextLine line in block.lines) {
        //Codes for the line
        for (TextElement element in line.elements) {
          //Codes for the elements
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
