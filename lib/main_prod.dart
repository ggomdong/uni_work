import 'main.dart' as app;

Future<void> main() async {
  await app.bootstrap(envFile: '.env.prod');
}
