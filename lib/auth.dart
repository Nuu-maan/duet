import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

Future<void> signInWithGoogle() async {
  final account = await GoogleSignIn.instance.authenticate();
  await FirebaseAuth.instance.signInWithCredential(
    GoogleAuthProvider.credential(idToken: account.authentication.idToken),
  );
}

Future<void> signOut() async {
  await GoogleSignIn.instance.signOut();
  await FirebaseAuth.instance.signOut();
}
