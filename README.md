<div align="center">

# 🌱 LexiFlow

### 📘 Learn Smarter. Remember Faster.

*A Modern, Secure & Intelligent Vocabulary Learning App*

[![Flutter](https://img.shields.io/badge/Flutter-3.24-blue?logo=flutter)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-orange)](#)
[![Status](https://img.shields.io/badge/Status-Production--Ready-success)](#)

---

**Developed by [Kiraken](https://github.com/erenuysl)**

</div>

<hr>

<h2>🚀 Overview</h2>
<p>
  LexiFlow is a modern Flutter + Firebase vocabulary learning app.  
  It offers categorized word lists, adaptive quizzes, progress tracking, and  
  <b>secure environment-based configuration</b> for production-grade reliability.
</p>

<hr>

<h2>⚙️ Installation &amp; Setup</h2>

<h3>1️⃣ Clone</h3>
<pre><code>git clone https://github.com/erenuysl/lexiflow.git
cd lexiflow
</code></pre>

<h3>2️⃣ Dependencies</h3>
<pre><code>flutter pub get
</code></pre>

<h3>3️⃣ .env (Environment)</h3>
<p>Copy <code>.env.example</code> to <code>.env</code> and add your Firebase configuration:</p>
<pre><code>cp .env.example .env
</code></pre>
<p>Then edit <code>.env</code> with your actual Firebase values from Firebase Console:</p>
<pre><code># Firebase Configuration
FIREBASE_API_KEY=your_firebase_api_key_here
FIREBASE_APP_ID=your_firebase_app_id_here
FIREBASE_MESSAGING_SENDER_ID=your_messaging_sender_id_here
FIREBASE_PROJECT_ID=your_project_id_here
FIREBASE_PROJECT_NUMBER=your_project_number_here
FIREBASE_STORAGE_BUCKET=your_storage_bucket_here

# AdMob Configuration  
ADMOB_APP_ID=your_admob_app_id_here
ADMOB_BANNER_AD_UNIT_ID=ca-app-pub-3940256099942544/6300978111
ADMOB_INTERSTITIAL_AD_UNIT_ID=ca-app-pub-3940256099942544/1033173712

DEBUG_MODE=true
</code></pre>
<p><b>⚠️ Important:</b> Never commit the <code>.env</code> file! Use <code>.env.example</code> as template.</p>

<hr>

<h2>🔥 Firebase Setup</h2>

<h3>1️⃣ Configure</h3>
<pre><code>flutterfire configure
</code></pre>

<h3>2️⃣ Local (Not Tracked)</h3>
<pre><code>android/app/google-services.json
ios/Runner/GoogleService-Info.plist
</code></pre>

<h3>3️⃣ Firestore Rules (Secure Example)</h3>
<pre><code>rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isOwner(userId) {
      return request.auth != null && request.auth.uid == userId;
    }

    match /users/{userId} {
      allow create: if isOwner(userId);
      allow read, update, delete: if isOwner(userId);

      match /learned_words/{wordId} {
        allow read, write: if isOwner(userId);
      }
      match /favorites/{wordId} {
        allow read, write: if isOwner(userId);
      }
      match /custom_words/{wordId} {
        allow read, write: if isOwner(userId);
      }
    }

    match /leaderboard_all_time/{userId} {
      allow read: if true;
      allow write: if isOwner(userId);
    }

    match /leaderboard_weekly/{userId} {
      allow read: if true;
      allow write: if isOwner(userId);
    }

    // Deny everything else by default
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
</code></pre>

<hr>

<h2>🧱 Project Structure</h2>
<pre><code>lexiflow/
├── android/
├── ios/
├── lib/
│   ├── models/
│   ├── screens/
│   ├── services/
│   ├── utils/
│   ├── widgets/
│   └── main.dart
├── assets/
│   ├── icons/
│   ├── images/
│   ├── animations/
│   ├── legal/
│   └── words/
├── store_assets/
│   ├── playstore.png
│   └── appstore.png
├── env/
│   ├── .env.dev
│   ├── .env.prod
│   └── .env.example
├── firestore.rules
├── pubspec.yaml
├── .gitignore
└── README.md
</code></pre>

<hr>

<h2>🔒 Security &amp; Privacy</h2>
<ul>
  <li>🔐 No API keys or secrets committed — all stored securely in <code>.env</code>.</li>
  <li>🧠 Firestore rules enforce per-user access (<code>request.auth.uid == userId</code>).</li>
  <li>🌍 Separate <code>.env.dev</code> / <code>.env.prod</code> environments.</li>
  <li>🧹 Debug logs protected with <code>kDebugMode</code>.</li>
  <li>⚙️ <code>.gitignore</code> fully excludes secrets, build files, and credentials.</li>
</ul>
<p><b>Recommendations:</b> Rotate keys every 3–6 months, add pre-commit hooks to block <code>.env</code>, enable GitHub secret scanning, and monitor Firebase usage.</p>

<hr>

<h2>🧪 Build &amp; Deployment</h2>

<h3>Debug</h3>
<pre><code>flutter run
</code></pre>

<h3>Release (Production)</h3>
<pre><code>flutter build appbundle --release
</code></pre>
<p><b>Android Note:</b> Enable <code>isMinifyEnabled = true</code>, <code>isShrinkResources = true</code>, and configure release signing locally only.</p>

<hr>

<h2>🧾 Release Checklist</h2>
<ul>
  <li>✅ No secrets in repository</li>
  <li>✅ <code>.env</code> properly configured</li>
  <li>✅ Firebase config secured</li>
  <li>✅ Obfuscation &amp; shrinking active</li>
  <li>✅ Dependencies updated</li>
  <li>✅ Firestore rules verified</li>
</ul>

<hr>

<h2>💡 Credits</h2>
<table>
  <thead>
    <tr><th>Role</th><th>Contributor</th></tr>
  </thead>
  <tbody>
    <tr><td>👨‍💻 Developer</td><td><a href="https://github.com/erenuysl">Kiraken</a></td></tr>
    <tr><td>🧩 Framework</td><td>Flutter 3.x</td></tr>
    <tr><td>☁️ Backend</td><td>Firebase Firestore &amp; Auth</td></tr>
    <tr><td>🎨 UI/UX</td><td>Minimal &amp; Responsive Custom Design</td></tr>
  </tbody>
</table>

<hr>

<p align="center">
  <img src="https://img.shields.io/badge/Security-Verified-brightgreen?style=for-the-badge" alt="Security Verified"><br>
  <b>LexiFlow — Clean, Secure, and Production-Ready.</b><br>
  ⭐ Star this repo → <a href="https://github.com/erenuysl/lexiflow">GitHub</a>
</p>
