import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'main.dart' as app;

void main() async {
  await dotenv.load(fileName: ".env.dev");
  app.main();
}
