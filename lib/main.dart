import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'services/firestore_service.dart';

const categories = [
  'Academic',
  'Examination',
  'Faculty',
  'Infrastructure',
  'Hostel',
  'Transport',
  'Library',
  'Canteen',
  'Fees',
  'IT/Technical',
  'Other',
];
const statuses = [
  'Submitted',
  'Under Review',
  'In Progress',
  'Resolved',
  'Rejected',
];
const priorities = ['Low', 'Medium', 'High', 'Urgent'];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'College Grievance Management',
    home: const AppGate(),
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff176b87)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xffd9e3e8)),
        ),
      ),
    ),
  );
}

class AppGate extends StatefulWidget {
  const AppGate({super.key});
  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  Future<void>? _firebase;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _firebase = Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final firebase = _firebase;
    if (firebase == null) return const LoginScreen();
    return FutureBuilder<void>(
      future: firebase,
      builder: (context, init) {
        if (init.connectionState != ConnectionState.done) {
          return const LoginScreen();
        }
        if (init.hasError) {
          return ErrorPage(
            message: init.error.toString(),
            onRetry: () => setState(
              () => _firebase = Firebase.initializeApp(
                options: DefaultFirebaseOptions.currentPlatform,
              ),
            ),
          );
        }
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, auth) {
            if (auth.connectionState == ConnectionState.waiting) {
              return const LoadingPage();
            }
            final user = auth.data;
            return user == null ? const LoginScreen() : RoleRouter(user: user);
          },
        );
      },
    );
  }
}

class RoleRouter extends StatelessWidget {
  const RoleRouter({required this.user, super.key});
  final User user;
  @override
  Widget build(BuildContext context) =>
      FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirestoreService.instance.profile(user.uid),
        builder: (context, snap) {
          if (!snap.hasData) return const LoadingPage();
          return snap.data!.data()?['role'] == 'admin'
              ? const AdminShell()
              : StudentShell(user: user);
        },
      );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false, hidden = true;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => error = authMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthMark(),
          const SizedBox(height: 24),
          Text(
            'College Grievance Management',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Login to continue',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: email,
            decoration: const InputDecoration(
              labelText: 'College email',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            validator: (v) =>
                v == null || !v.contains('@') ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: password,
            obscureText: hidden,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () => setState(() => hidden = !hidden),
                icon: Icon(
                  hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (v) =>
                v == null || v.isEmpty ? 'Enter your password' : null,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ResetDialog(email: email),
              ),
              child: const Text('Forgot Password?'),
            ),
          ),
          if (error != null) ErrorBanner(message: error!),
          FilledButton(
            onPressed: busy ? null : login,
            child: busy ? const ProgressIcon() : const Text('Login'),
          ),
          const SizedBox(height: 16),
          AuthLink(
            prefix: "Don't have an account?",
            label: 'Sign Up',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const SignUpScreen()),
            ),
          ),
        ],
      ),
    ),
  );
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpState();
}

class _SignUpState extends State<SignUpScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      student = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController();
  String department = 'Computer Science', year = '1st Year';
  bool busy = false;
  String? error;
  @override
  void dispose() {
    for (final c in [name, student, email, password, confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    if (password.text != confirm.text) {
      setState(() => error = 'Passwords do not match.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text,
      );
      await cred.user!.updateDisplayName(name.text.trim());
      await FirestoreService.instance.createProfile(
        user: cred.user!,
        name: name.text.trim(),
        studentId: student.text.trim(),
        department: department,
        year: year,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => error = authMessage(e));
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create your account')),
    body: SafeArea(
      child: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const AuthMark(),
            const SizedBox(height: 20),
            Text(
              'Join College Grievance Management',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 24),
            field(name, 'Full Name', Icons.person_outline),
            field(email, 'College Email', Icons.mail_outline, emailType: true),
            field(student, 'Student / Register Number', Icons.badge_outlined),
            dropdown('Department', department, [
              'Computer Science',
              'Information Technology',
              'Business',
              'Engineering',
              'Arts and Science',
            ], (v) => setState(() => department = v!)),
            dropdown('Year', year, [
              '1st Year',
              '2nd Year',
              '3rd Year',
              '4th Year',
            ], (v) => setState(() => year = v!)),
            field(password, 'Password', Icons.lock_outline, passwordType: true),
            field(
              confirm,
              'Confirm Password',
              Icons.verified_user_outlined,
              passwordType: true,
            ),
            if (error != null) ErrorBanner(message: error!),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: busy ? null : submit,
              child: busy ? const ProgressIcon() : const Text('Create Account'),
            ),
            AuthLink(
              prefix: 'Already have an account?',
              label: 'Login',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    ),
  );
  Widget field(
    TextEditingController c,
    String label,
    IconData icon, {
    bool emailType = false,
    bool passwordType = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: c,
      obscureText: passwordType,
      keyboardType: emailType ? TextInputType.emailAddress : null,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: (v) => v == null || v.trim().isEmpty
          ? 'Required'
          : emailType && !v.contains('@')
          ? 'Enter a valid email'
          : passwordType && v.length < 6
          ? 'Use at least 6 characters'
          : null,
    ),
  );
  Widget dropdown(
    String label,
    String value,
    List<String> values,
    ValueChanged<String?> onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: values
          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
          .toList(),
      onChanged: onChanged,
    ),
  );
}

class StudentShell extends StatefulWidget {
  const StudentShell({required this.user, super.key});
  final User user;
  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      StudentHome(user: widget.user, onRaise: () => setState(() => tab = 1)),
      const RaiseGrievance(),
      const MyGrievances(),
      const ProfileScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          [
            'Student Dashboard',
            'Raise Grievance',
            'My Grievances',
            'Profile',
          ][tab],
        ),
        actions: [
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            label: 'Raise',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            label: 'My Grievances',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class StudentHome extends StatelessWidget {
  const StudentHome({required this.user, required this.onRaise, super.key});
  final User user;
  final VoidCallback onRaise;
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirestoreService.instance.studentGrievances(user.uid),
    builder: (context, snap) {
      final docs = snap.data?.docs ?? [];
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Welcome back, ${user.displayName?.isNotEmpty == true ? user.displayName : 'Student'}',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              MetricCard(label: 'Total', value: '${docs.length}'),
              ...statuses
                  .take(4)
                  .map(
                    (s) => MetricCard(
                      label: s,
                      value:
                          '${docs.where((d) => d.data()['status'] == s).length}',
                    ),
                  ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRaise,
            icon: const Icon(Icons.add),
            label: const Text('Raise Grievance'),
          ),
          const SizedBox(height: 24),
          const Text(
            'Recent grievances',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          if (docs.isEmpty)
            const EmptyState(message: 'No grievances submitted yet.'),
          ...docs
              .take(3)
              .map(
                (d) => GrievanceCard(
                  data: d.data(),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => GrievanceDetails(data: d.data()),
                    ),
                  ),
                ),
              ),
        ],
      );
    },
  );
}

class RaiseGrievance extends StatefulWidget {
  const RaiseGrievance({super.key});
  @override
  State<RaiseGrievance> createState() => _RaiseState();
}

class _RaiseState extends State<RaiseGrievance> {
  final form = GlobalKey<FormState>();
  final subject = TextEditingController(),
      description = TextEditingController();
  String category = categories.first, priority = 'Medium';
  bool busy = false;
  @override
  void dispose() {
    subject.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final u = FirestoreService.instance.currentUser;
      final p = await FirestoreService.instance.profile(u.uid);
      final id = await FirestoreService.instance.createGrievance(
        category: category,
        subject: subject.text.trim(),
        description: description.text.trim(),
        priority: priority,
        studentName: p.data()?['name'] ?? 'Student',
        studentEmail: u.email ?? '',
      );
      if (mounted)
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Grievance submitted'),
            content: Text('Your grievance ID is $id'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not submit grievance: $e')),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Tell us what happened',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          value: category,
          decoration: const InputDecoration(labelText: 'Category'),
          items: categories
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: (v) => setState(() => category = v!),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: subject,
          decoration: const InputDecoration(labelText: 'Subject'),
          validator: required,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: description,
          minLines: 6,
          maxLines: 10,
          decoration: const InputDecoration(labelText: 'Description'),
          validator: required,
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          value: priority,
          decoration: const InputDecoration(labelText: 'Priority'),
          items: priorities
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: (v) => setState(() => priority = v!),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: busy ? null : save,
          icon: busy ? const ProgressIcon() : const Icon(Icons.send),
          label: const Text('Submit grievance'),
        ),
      ],
    ),
  );
}

class MyGrievances extends StatefulWidget {
  const MyGrievances({super.key});
  @override
  State<MyGrievances> createState() => _MyState();
}

class _MyState extends State<MyGrievances> {
  String query = '', filter = 'All';
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: 'Search grievances',
          ),
          onChanged: (v) => setState(() => query = v.toLowerCase()),
        ),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ['All', ...statuses]
              .map(
                (s) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(s),
                    selected: filter == s,
                    onSelected: (_) => setState(() => filter = s),
                  ),
                ),
              )
              .toList(),
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreService.instance.studentGrievances(
            FirebaseAuth.instance.currentUser!.uid,
          ),
          builder: (context, snap) {
            final docs = (snap.data?.docs ?? []).where((d) {
              final x = d.data();
              return (filter == 'All' || x['status'] == filter) &&
                  ('$x'.toLowerCase().contains(query));
            }).toList();
            return docs.isEmpty
                ? const EmptyState(message: 'No matching grievances.')
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: docs.map((d) {
                      return GrievanceCard(
                        data: d.data(),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => GrievanceDetails(data: d.data()),
                          ),
                        ),
                      );
                    }).toList(),
                  );
          },
        ),
      ),
    ],
  );
}

class GrievanceDetails extends StatelessWidget {
  const GrievanceDetails({required this.data, super.key});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final index = statuses.indexOf(data['status'] ?? 'Submitted');
    return Scaffold(
      appBar: AppBar(title: const Text('Grievance details')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            data['subject'] ?? '',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text('ID: ${data['grievanceId']}'),
          const SizedBox(height: 16),
          InfoRow(label: 'Category', value: data['category']),
          InfoRow(label: 'Priority', value: data['priority']),
          InfoRow(label: 'Description', value: data['description']),
          const SizedBox(height: 20),
          const Text(
            'Status timeline',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          ...statuses
              .take(4)
              .toList()
              .asMap()
              .entries
              .map(
                (e) => ListTile(
                  leading: Icon(
                    e.key <= index
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(e.value),
                ),
              ),
          if ((data['adminResponse'] ?? '').toString().isNotEmpty)
            InfoRow(label: 'Admin response', value: data['adminResponse']),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileState();
}

class _ProfileState extends State<ProfileScreen> {
  final name = TextEditingController(),
      student = TextEditingController(),
      department = TextEditingController(),
      year = TextEditingController();
  bool loaded = false, busy = false;
  @override
  void dispose() {
    for (final c in [name, student, department, year]) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirestoreService.instance.profile(
          FirebaseAuth.instance.currentUser!.uid,
        ),
        builder: (context, snap) {
          if (snap.hasData && !loaded) {
            final d = snap.data!.data() ?? {};
            name.text = d['name'] ?? '';
            student.text = d['studentId'] ?? '';
            department.text = d['department'] ?? '';
            year.text = d['year'] ?? '';
            loaded = true;
          }
          if (!snap.hasData) return const LoadingPage();
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const AuthMark(),
              const SizedBox(height: 20),
              Text(
                'Your profile',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              ...[name, student, department, year].asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: TextField(
                    controller: e.value,
                    decoration: InputDecoration(
                      labelText: [
                        'Name',
                        'Student ID',
                        'Department',
                        'Year',
                      ][e.key],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        setState(() => busy = true);
                        await FirestoreService.instance.updateProfile(
                          name: name.text,
                          studentId: student.text,
                          department: department.text,
                          year: year.text,
                        );
                        if (mounted) {
                          setState(() => busy = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Profile saved')),
                          );
                        }
                      },
                child: busy ? const ProgressIcon() : const Text('Save profile'),
              ),
            ],
          );
        },
      );
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      const AdminHome(),
      const AdminGrievances(),
      const AdminStudents(),
      const StatisticsScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          [
            'Admin Dashboard',
            'All Grievances',
            'Students',
            'Statistics',
            'Profile',
          ][tab],
        ),
        actions: [
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            label: 'Grievances',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            label: 'Students',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart),
            label: 'Statistics',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirestoreService.instance.allGrievances(),
    builder: (context, snap) {
      final docs = snap.data?.docs ?? [];
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Operations overview',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              MetricCard(label: 'Total', value: '${docs.length}'),
              ...statuses.map(
                (s) => MetricCard(
                  label: s,
                  value: '${docs.where((d) => d.data()['status'] == s).length}',
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

class AdminGrievances extends StatefulWidget {
  const AdminGrievances({super.key});
  @override
  State<AdminGrievances> createState() => _AdminGrievancesState();
}

class _AdminGrievancesState extends State<AdminGrievances> {
  String query = '', filter = 'All';
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: 'Search all grievances',
          ),
          onChanged: (v) => setState(() => query = v.toLowerCase()),
        ),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ['All', ...statuses]
              .map(
                (s) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(s),
                    selected: filter == s,
                    onSelected: (_) => setState(() => filter = s),
                  ),
                ),
              )
              .toList(),
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreService.instance.allGrievances(),
          builder: (context, snap) {
            final docs = (snap.data?.docs ?? []).where((d) {
              final x = d.data();
              return (filter == 'All' || x['status'] == filter) &&
                  ('$x'.toLowerCase().contains(query));
            }).toList();
            return ListView(
              padding: const EdgeInsets.all(20),
              children: docs.map((d) {
                return GrievanceCard(
                  data: d.data(),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => AdminEditor(data: d.data()),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    ],
  );
}

class AdminEditor extends StatefulWidget {
  const AdminEditor({required this.data, super.key});

  final Map<String, dynamic> data;

  @override
  State<AdminEditor> createState() => _EditorState();
}

class _EditorState extends State<AdminEditor> {
  late String status;
  late final TextEditingController response;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    status = widget.data['status'] ?? 'Submitted';
    response = TextEditingController(text: widget.data['adminResponse'] ?? '');
  }

  @override
  void dispose() {
    response.dispose();
    super.dispose();
  }

  Future<void> saveChanges() async {
    setState(() => busy = true);

    try {
      await FirestoreService.instance.updateGrievance(
        widget.data['grievanceId'],
        status: status,
        response: response.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Changes saved successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save changes: $e')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Manage grievance')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          widget.data['subject'] ?? 'Untitled',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text('ID: ${widget.data['grievanceId'] ?? '-'}'),
        const SizedBox(height: 20),

        InfoRow(label: 'Category', value: widget.data['category']),
        InfoRow(label: 'Priority', value: widget.data['priority']),
        InfoRow(label: 'Description', value: widget.data['description']),
        InfoRow(label: 'Student', value: widget.data['studentName']),
        InfoRow(label: 'Email', value: widget.data['studentEmail']),

        const SizedBox(height: 20),

        DropdownButtonFormField<String>(
          value: status,
          decoration: const InputDecoration(
            labelText: 'Status',
            border: OutlineInputBorder(),
          ),
          items: statuses
              .map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
              .toList(),
          onChanged: busy
              ? null
              : (value) {
                  if (value != null) {
                    setState(() => status = value);
                  }
                },
        ),

        const SizedBox(height: 16),

        TextField(
          controller: response,
          maxLines: 5,
          enabled: !busy,
          decoration: const InputDecoration(
            labelText: 'Admin response',
            hintText: 'Enter your response...',
            border: OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: busy ? null : saveChanges,
            child: busy ? const ProgressIcon() : const Text('Save changes'),
          ),
        ),
      ],
    ),
  );
}

class AdminStudents extends StatelessWidget {
  const AdminStudents({super.key});

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance.collection('users').snapshots(),
    builder: (context, snap) {
      if (snap.hasError) {
        return Center(child: Text('Could not load students: ${snap.error}'));
      }

      if (!snap.hasData) {
        return const LoadingPage();
      }

      final students = snap.data!.docs.where((doc) {
        final data = doc.data();
        return data['role'] != 'admin';
      }).toList();

      if (students.isEmpty) {
        return const EmptyState(message: 'No registered students yet.');
      }

      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '${students.length} registered student${students.length == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),

          ...students.map((doc) {
            final data = doc.data();

            final name = (data['name'] ?? 'Student').toString();
            final email = (data['email'] ?? '').toString();
            final studentId = (data['studentId'] ?? '').toString();
            final department = (data['department'] ?? '').toString();

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(child: const Icon(Icons.person)),
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  [
                    if (email.isNotEmpty) email,
                    if (studentId.isNotEmpty) studentId,
                    if (department.isNotEmpty) department,
                  ].join(' · '),
                ),
              ),
            );
          }),
        ],
      );
    },
  );
}

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.instance.allGrievances(),
        builder: (context, snap) {
          final docs = snap.data?.docs.map((d) => d.data()).toList() ?? [];
          Widget group(String title, List<String> values, String key) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              ...values.map(
                (v) => ListTile(
                  title: Text(v),
                  trailing: Text('${docs.where((d) => d[key] == v).length}'),
                ),
              ),
            ],
          );
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              group('By status', statuses, 'status'),
              group('By category', categories, 'category'),
              group('By priority', priorities, 'priority'),
            ],
          );
        },
      );
}

class ResetDialog extends StatefulWidget {
  const ResetDialog({required this.email, super.key});
  final TextEditingController email;
  @override
  State<ResetDialog> createState() => _ResetState();
}

class _ResetState extends State<ResetDialog> {
  String? message;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Reset password'),
    content: TextField(
      controller: widget.email,
      decoration: const InputDecoration(labelText: 'College email'),
    ),
    actions: [
      if (message != null) Text(message!),
      TextButton(
        onPressed: () async {
          try {
            await FirebaseAuth.instance.sendPasswordResetEmail(
              email: widget.email.text.trim(),
            );
            if (mounted) setState(() => message = 'Reset email sent.');
          } on FirebaseAuthException catch (e) {
            if (mounted) setState(() => message = authMessage(e));
          }
        },
        child: const Text('Send email'),
      ),
    ],
  );
}

String? required(String? v) =>
    v == null || v.trim().isEmpty ? 'Required' : null;
String authMessage(FirebaseAuthException e) => switch (e.code) {
  'invalid-credential' ||
  'user-not-found' ||
  'wrong-password' => 'The email or password is incorrect.',
  'email-already-in-use' => 'An account already exists for this email.',
  'invalid-email' => 'Enter a valid college email address.',
  'weak-password' => 'Choose a stronger password.',
  'too-many-requests' => 'Too many attempts. Try again later.',
  _ => e.message ?? 'Authentication failed.',
};

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xffeef5f6),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: child,
          ),
        ),
      ),
    ),
  );
}

class AuthMark extends StatelessWidget {
  const AuthMark({super.key});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      height: 54,
      width: 54,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.account_balance, color: Colors.white, size: 28),
    ),
  );
}

class AuthLink extends StatelessWidget {
  const AuthLink({
    required this.prefix,
    required this.label,
    required this.onPressed,
    super.key,
  });
  final String prefix, label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    children: [
      Text(prefix),
      TextButton(onPressed: onPressed, child: Text(label)),
    ],
  );
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({required this.message, super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xffffe9e7),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(message, style: const TextStyle(color: Color(0xffa32922))),
  );
}

class ProgressIcon extends StatelessWidget {
  const ProgressIcon({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 20,
    width: 20,
    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
  );
}

class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class ErrorPage extends StatelessWidget {
  const ErrorPage({required this.message, required this.onRetry, super.key});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({required this.message, super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.black54),
      ),
    ),
  );
}

class MetricCard extends StatelessWidget {
  const MetricCard({required this.label, required this.value, super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(label),
        ],
      ),
    ),
  );
}

class GrievanceCard extends StatelessWidget {
  const GrievanceCard({required this.data, required this.onTap, super.key});
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      title: Text(data['subject'] ?? 'Untitled'),
      subtitle: Text('${data['category']} · ${data['priority']}'),
      trailing: Chip(label: Text(data['status'] ?? 'Submitted')),
    ),
  );
}

class InfoRow extends StatelessWidget {
  const InfoRow({required this.label, required this.value, super.key});
  final String label;
  final dynamic value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(child: Text(value?.toString() ?? '-')),
      ],
    ),
  );
}
