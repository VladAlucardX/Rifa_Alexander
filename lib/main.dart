import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Credenciales de Supabase
const String supabaseUrl = 'https://zptpxjbdkjoborgenytn.supabase.co';
const String supabaseAnonKey = 'sb_publishable_hlOlULjiXJPiA6rinDLg9A_lUVuu8v5';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rifa Alexander App',
      theme: ThemeData(
        // Tema principal de la aplicación con color rojo
        primarySwatch: Colors.red,
        // Usar un esquema de color de semillas para consistencia
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session;
        if (session == null) {
          return const LoginScreen();
        } else {
          return FutureBuilder<Map<String, dynamic>?>(
            future: _getProfile(session.user.id),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final profile = profileSnapshot.data;
              if (profile == null) {
                return const Scaffold(
                  body: Center(child: Text('Error al cargar perfil')),
                );
              }

              final rol = profile['rol'];
              if (rol == 'admin') {
                return const AdminDashboard();
              } else if (rol == 'vendedor') {
                return const VentaPage();
              } else {
                return const Scaffold(
                  body: Center(child: Text('Rol no reconocido')),
                );
              }
            },
          );
        }
      },
    );
  }

  Future<Map<String, dynamic>?> _getProfile(String userId) async {
    try {
      debugPrint('Consultando perfil para userId: $userId');
      final response = await Supabase.instance.client
          .from('perfiles')
          .select('rol')
          .eq('id', userId)
          .single();
      debugPrint('Perfil obtenido: $response');
      return response;
    } catch (e) {
      debugPrint('Error al obtener perfil: $e');
      return null;
    }
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al iniciar sesión: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Iniciar Sesión'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Contraseña'),
              obscureText: true,
            ),
            const SizedBox(height: 32),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _signIn,
                    child: const Text('Iniciar Sesión'),
                  ),
          ],
        ),
      ),
    );
  }
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  double _totalVentasHoy = 0.0;
  bool _isLoadingVentas = true;

  @override
  void initState() {
    super.initState();
    _getTotalVentasHoy();
  }

  Future<void> _getTotalVentasHoy() async {
    setState(() {
      _isLoadingVentas = true;
    });

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
      final endOfDay = DateTime(now.year, now.month, now.day + 1).toIso8601String();

      final response = await Supabase.instance.client
          .from('ventas')
          .select('monto')
          .gte('fecha_hora', startOfDay)
          .lt('fecha_hora', endOfDay);

      final data = response as List<dynamic>;
      final total = data.map((e) => (e['monto'] as num).toDouble()).fold(0.0, (a, b) => a + b);

      setState(() {
        _totalVentasHoy = total;
        _isLoadingVentas = false;
      });
    } catch (e) {
      debugPrint('Error al obtener ventas: $e');
      setState(() {
        _isLoadingVentas = false;
      });
    }
  }

  void _showRegisterDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Registrar Nuevo Vendedor'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'Contraseña'),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setState(() {
                        isLoading = true;
                      });
                      try {
                        await Supabase.instance.client.auth.signUp(
                          email: emailController.text.trim(),
                          password: passwordController.text,
                        );
                        if (mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Vendedor registrado exitosamente')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() {
                            isLoading = false;
                          });
                        }
                      }
                    },
              child: isLoading ? const CircularProgressIndicator() : const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administrador'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _showRegisterDialog,
              child: const Text('Registrar Nuevo Vendedor'),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Ventas Totales del Día',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    _isLoadingVentas
                        ? const CircularProgressIndicator()
                        : Text(
                            'C\$${ _totalVentasHoy.toStringAsFixed(2) }',
                            style: const TextStyle(fontSize: 24, color: Colors.green),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VentaPage extends StatelessWidget {
  const VentaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Página de Ventas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('Página de Ventas'),
      ),
    );
  }
}