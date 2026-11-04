import 'dart:math';
import 'package:flutter/material.dart';

/// Pure-Dart QR Code (Version 1-4, Model 2) Generator and Painter.
/// Zero external pub packages required.
class QrCodeWidget extends StatelessWidget {
  final String data;
  final double size;
  final Color foregroundColor;
  final Color backgroundColor;

  const QrCodeWidget({
    super.key,
    required this.data,
    this.size = 200,
    this.foregroundColor = Colors.black,
    this.backgroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final matrix = _QrEncoder.encode(data);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.05),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: _QrPainter(
          matrix: matrix,
          foregroundColor: foregroundColor,
        ),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  final List<List<bool>> matrix;
  final Color foregroundColor;

  _QrPainter({required this.matrix, required this.foregroundColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = foregroundColor
      ..style = PaintingStyle.fill;

    final n = matrix.length;
    if (n == 0) return;

    final cellSize = size.width / n;

    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        if (matrix[r][c]) {
          final rect = Rect.fromLTWH(
            c * cellSize,
            r * cellSize,
            cellSize,
            cellSize,
          );
          canvas.drawRect(rect, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) =>
      oldDelegate.matrix != matrix ||
      oldDelegate.foregroundColor != foregroundColor;
}

class _QrEncoder {
  static final List<int> _exp = List<int>.filled(512, 0);
  static final List<int> _log = List<int>.filled(256, 0);
  static bool _tablesInit = false;

  static void _initTables() {
    if (_tablesInit) return;
    int x = 1;
    for (int i = 0; i < 255; i++) {
      _exp[i] = x;
      _exp[i + 255] = x;
      _log[x] = i;
      x <<= 1;
      if ((x & 0x100) != 0) {
        x ^= 0x11D;
      }
    }
    _tablesInit = true;
  }

  static int _gMul(int a, int b) {
    if (a == 0 || b == 0) return 0;
    return _exp[(_log[a] + _log[b]) % 255];
  }

  static List<int> _rsEncode(List<int> data, int ecCount) {
    _initTables();
    List<int> poly = [1];
    for (int i = 0; i < ecCount; i++) {
      final nextPoly = List<int>.filled(poly.length + 1, 0);
      for (int j = 0; j < poly.length; j++) {
        nextPoly[j] ^= _gMul(poly[j], _exp[i]);
        nextPoly[j + 1] ^= poly[j];
      }
      poly = nextPoly;
    }

    final res = List<int>.filled(ecCount, 0);
    for (final byte in data) {
      final factor = byte ^ res[0];
      for (int i = 0; i < ecCount - 1; i++) {
        res[i] = res[i + 1];
      }
      res[ecCount - 1] = 0;
      for (int j = 0; j < ecCount; j++) {
        res[j] ^= _gMul(poly[ecCount - 1 - j], factor);
      }
    }
    return res;
  }

  static List<List<bool>> encode(String text) {
    _initTables();
    final bytes = text.codeUnits;

    // Pick Version based on length (Level L)
    // Vers 1: up to 17 bytes, Vers 2: up to 32 bytes, Vers 3: up to 53 bytes, Vers 4: up to 78 bytes
    int version = 3;
    int dataCapacity = 55;
    int ecCount = 15;
    int alignmentPattern = 22;

    if (bytes.length <= 14) {
      version = 1;
      dataCapacity = 19;
      ecCount = 7;
      alignmentPattern = 0;
    } else if (bytes.length <= 28) {
      version = 2;
      dataCapacity = 34;
      ecCount = 10;
      alignmentPattern = 18;
    } else if (bytes.length <= 50) {
      version = 3;
      dataCapacity = 55;
      ecCount = 15;
      alignmentPattern = 22;
    } else {
      version = 4;
      dataCapacity = 80;
      ecCount = 20;
      alignmentPattern = 26;
    }

    final matrixSize = 17 + version * 4;

    // 1. Bitstream builder
    final bitStream = <int>[];
    void putBits(int val, int count) {
      for (int i = count - 1; i >= 0; i--) {
        bitStream.add((val >> i) & 1);
      }
    }

    // Mode: Byte (0100)
    putBits(4, 4);
    // Char count indicator (8 bits for Vers 1-9)
    putBits(bytes.length, 8);
    // Data bytes
    for (final b in bytes) {
      putBits(b, 8);
    }

    // Terminator (0000)
    final neededBits = dataCapacity * 8;
    final termLen = min(4, neededBits - bitStream.length);
    putBits(0, termLen);

    // Padding to byte boundary
    while (bitStream.length % 8 != 0) {
      bitStream.add(0);
    }

    // Pad bytes 0xEC, 0x11
    final dataCodewords = <int>[];
    for (int i = 0; i < bitStream.length; i += 8) {
      int byte = 0;
      for (int b = 0; b < 8; b++) {
        byte = (byte << 1) | bitStream[i + b];
      }
      dataCodewords.add(byte);
    }

    int padToggle = 0;
    while (dataCodewords.length < dataCapacity) {
      dataCodewords.add(padToggle == 0 ? 0xEC : 0x11);
      padToggle ^= 1;
    }

    // 2. Reed-Solomon Error Correction Codewords
    final ecCodewords = _rsEncode(dataCodewords, ecCount);

    final allCodewords = [...dataCodewords, ...ecCodewords];
    final finalBits = <int>[];
    for (final c in allCodewords) {
      for (int b = 7; b >= 0; b--) {
        finalBits.add((c >> b) & 1);
      }
    }

    // 3. Matrix Setup
    final matrix =
        List.generate(matrixSize, (_) => List<bool?>.filled(matrixSize, null));
    final reserved =
        List.generate(matrixSize, (_) => List<bool>.filled(matrixSize, false));

    // Finder patterns
    void setFinder(int row, int col) {
      for (int r = -1; r <= 7; r++) {
        for (int c = -1; c <= 7; c++) {
          final mr = row + r;
          final mc = col + c;
          if (mr >= 0 && mr < matrixSize && mc >= 0 && mc < matrixSize) {
            reserved[mr][mc] = true;
            if ((r >= 0 && r <= 6 && (c == 0 || c == 6)) ||
                (c >= 0 && c <= 6 && (r == 0 || r == 6)) ||
                (r >= 2 && r <= 4 && c >= 2 && c <= 4)) {
              matrix[mr][mc] = true;
            } else {
              matrix[mr][mc] = false;
            }
          }
        }
      }
    }

    setFinder(0, 0);
    setFinder(0, matrixSize - 7);
    setFinder(matrixSize - 7, 0);

    // Timing patterns
    for (int i = 8; i < matrixSize - 8; i++) {
      if (!reserved[6][i]) {
        reserved[6][i] = true;
        matrix[6][i] = (i % 2 == 0);
      }
      if (!reserved[i][6]) {
        reserved[i][6] = true;
        matrix[i][6] = (i % 2 == 0);
      }
    }

    // Alignment pattern
    if (alignmentPattern > 0) {
      final ar = alignmentPattern;
      final ac = alignmentPattern;
      for (int r = -2; r <= 2; r++) {
        for (int c = -2; c <= 2; c++) {
          final mr = ar + r;
          final mc = ac + c;
          if (!reserved[mr][mc]) {
            reserved[mr][mc] = true;
            matrix[mr][mc] = (max(r.abs(), c.abs()) != 1);
          }
        }
      }
    }

    // Dark module
    reserved[matrixSize - 8][8] = true;
    matrix[matrixSize - 8][8] = true;

    // Reserve format information areas
    for (int i = 0; i <= 8; i++) {
      reserved[8][i] = true;
      reserved[i][8] = true;
    }
    for (int i = 0; i < 8; i++) {
      reserved[8][matrixSize - 1 - i] = true;
      reserved[matrixSize - 1 - i][8] = true;
    }

    // 4. Data bit placement in zigzag columns
    int bitIndex = 0;
    int dir = -1; // up
    for (int c = matrixSize - 1; c > 0; c -= 2) {
      if (c == 6) c--; // Skip vertical timing column
      int r = (dir == -1) ? (matrixSize - 1) : 0;
      while (r >= 0 && r < matrixSize) {
        for (int colOffset = 0; colOffset < 2; colOffset++) {
          final cc = c - colOffset;
          if (!reserved[r][cc]) {
            bool bit = false;
            if (bitIndex < finalBits.length) {
              bit = (finalBits[bitIndex] == 1);
              bitIndex++;
            }
            // Apply mask 0: (row + col) % 2 == 0
            if ((r + cc) % 2 == 0) {
              bit = !bit;
            }
            matrix[r][cc] = bit;
          }
        }
        r += dir;
      }
      dir = -dir;
    }

    // 5. Format info (Level L, Mask 0): 0b111011111000100 ^ 0b101010000010010 = 0x77C4 (0b010001111010110)
    const formatBits = [0, 1, 0, 0, 0, 1, 1, 1, 1, 0, 1, 0, 1, 1, 0];
    // Place on top-left
    for (int i = 0; i <= 5; i++) {
      matrix[8][i] = (formatBits[i] == 1);
    }
    matrix[8][7] = (formatBits[6] == 1);
    matrix[8][8] = (formatBits[7] == 1);
    matrix[7][8] = (formatBits[8] == 1);
    for (int i = 9; i < 15; i++) {
      matrix[14 - i][8] = (formatBits[i] == 1);
    }

    // Place on bottom-left and top-right
    for (int i = 0; i < 7; i++) {
      matrix[matrixSize - 1 - i][8] = (formatBits[i] == 1);
    }
    for (int i = 0; i < 8; i++) {
      matrix[8][matrixSize - 8 + i] = (formatBits[7 + i] == 1);
    }

    return List.generate(matrixSize,
        (r) => List.generate(matrixSize, (c) => matrix[r][c] ?? false));
  }
}
