/// 原生平台 HTTP Client（使用系统 CA 验证证书）
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

http.Client createPlatformClient() {
  final client = HttpClient();
  return IOClient(client);
}
