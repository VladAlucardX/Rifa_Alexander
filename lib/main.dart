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
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
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
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final navigator = Navigator.of(dialogContext);
                      final errorMessenger = ScaffoldMessenger.of(dialogContext);
                      setState(() {
                        isLoading = true;
                      });
                      try {
                        await Supabase.instance.client.auth.signUp(
                          email: emailController.text.trim(),
                          password: passwordController.text,
                        );
                        navigator.pop();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Vendedor registrado exitosamente')),
                        );
                      } catch (e) {
                        errorMessenger.showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      } finally {
                        setState(() {
                          isLoading = false;
                        });
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

class VentaPage extends StatefulWidget {
  const VentaPage({super.key});

  @override
  State<VentaPage> createState() => _VentaPageState();
}

class _VentaPageState extends State<VentaPage> {
  List<Map<String, dynamic>> _juegos = [];
  bool _isLoadingJuegos = true;
  Map<String, dynamic>? _selectedJuego;
  final _numeroController = TextEditingController();
  final _montoController = TextEditingController();
  bool _isVending = false;

  @override
  void initState() {
    super.initState();
    _loadJuegos();
  }

  Future<void> _loadJuegos() async {
    try {
      final response = await Supabase.instance.client.from('juegos').select('id, nombre');
      setState(() {
        _juegos = List<Map<String, dynamic>>.from(response);
        _isLoadingJuegos = false;
      });
    } catch (e) {
      debugPrint('Error cargando juegos: $e');
      setState(() {
        _isLoadingJuegos = false;
      });
    }
  }

  Future<void> _vender() async {
    if (_selectedJuego == null || _numeroController.text.isEmpty || _montoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos')),
      );
      return;
    }

    setState(() {
      _isVending = true;
    });

    try {
      final ventaData = {
        'juego_id': _selectedJuego!['id'],
        'numero_jugado': int.parse(_numeroController.text),
        'monto': double.parse(_montoController.text),
        'fecha_hora': DateTime.now().toIso8601String(),
        'vendedor_id': Supabase.instance.client.auth.currentUser!.id,
      };

      final response = await Supabase.instance.client
          .from('ventas')
          .insert(ventaData)
          .select('id')
          .single();

      final ticketId = response['id'];

      _numeroController.clear();
      _montoController.clear();
      setState(() {
        _selectedJuego = null;
      });

      _showTicketDialog(ticketId, ventaData);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al vender: $e')),
      );
    } finally {
      setState(() {
        _isVending = false;
      });
    }
  }

  void _showTicketDialog(int ticketId, Map<String, dynamic> ventaData) {
    final fecha = DateTime.parse(ventaData['fecha_hora']);
    final fechaStr = '${fecha.day}/${fecha.month}/${fecha.year}';
    final horaStr = '${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        child: Container(
          padding: const EdgeInsets.all(20),
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'LOTO NICARAGUA',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Fecha: $fechaStr',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              Text(
                'Hora: $horaStr',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 10),
              Text(
                'Juego: ${_selectedJuego!['nombre']}',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              Text(
                'Número: ${ventaData['numero_jugado']}',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              Text(
                'Monto: C\$${ventaData['monto']}',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 10),
              Text(
                'Ticket #: $ticketId',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Listo'),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoadingJuegos
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: _selectedJuego,
                    decoration: const InputDecoration(labelText: 'Juego'),
                    items: _juegos.map((juego) {
                      return DropdownMenuItem(
                        value: juego,
                        child: Text(juego['nombre']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedJuego = value;
                      });
                    },
                  ),
                  TextField(
                    controller: _numeroController,
                    decoration: const InputDecoration(labelText: 'Número Jugado'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: _montoController,
                    decoration: const InputDecoration(labelText: 'Monto C\$'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),
                  _isVending
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _vender,
                          child: const Text('Vender'),
                        ),
                ],
              ),
      ),
    );
  }
}