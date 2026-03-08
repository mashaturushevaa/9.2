import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Ініціалізація Hive (працює на Windows, Web, Mobile)
  await Hive.initFlutter();
  
  // 2. Реєструємо адаптер (написаний вручну, щоб уникнути помилок кодогенерації)
  Hive.registerAdapter(RecipeAdapter());
  
  // 3. Відкриваємо "коробку" (аналог таблиці в базі даних)
  await Hive.openBox<Recipe>('recipesBox');

  runApp(const RecipeBookApp());
}

// ==========================================
// 1. МОДЕЛЬ ДАНИХ ТА АДАПТЕР
// ==========================================
class Recipe {
  String id;
  String name;
  String description;
  String category;
  int timeMinutes;
  bool isFavorite;
  String ingredients; // Для простоти зберігаємо як текст
  String steps;

  Recipe({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.timeMinutes,
    this.isFavorite = false,
    required this.ingredients,
    required this.steps,
  });
}

// Адаптер для збереження об'єкта в Hive
class RecipeAdapter extends TypeAdapter<Recipe> {
  @override
  final int typeId = 0;

  @override
  Recipe read(BinaryReader reader) {
    final map = reader.readMap();
    return Recipe(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      category: map['category'],
      timeMinutes: map['timeMinutes'],
      isFavorite: map['isFavorite'],
      ingredients: map['ingredients'],
      steps: map['steps'],
    );
  }

  @override
  void write(BinaryWriter writer, Recipe obj) {
    writer.writeMap({
      'id': obj.id,
      'name': obj.name,
      'description': obj.description,
      'category': obj.category,
      'timeMinutes': obj.timeMinutes,
      'isFavorite': obj.isFavorite,
      'ingredients': obj.ingredients,
      'steps': obj.steps,
    });
  }
}

// ==========================================
// 2. ГОЛОВНИЙ ЕКРАН (СПИСОК ТА ПОШУК)
// ==========================================
class RecipeBookApp extends StatelessWidget {
  const RecipeBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Recipe Book',
      theme: ThemeData(primarySwatch: Colors.orange, useMaterial3: false),
      home: const RecipeListScreen(),
    );
  }
}

class RecipeListScreen extends StatefulWidget {
  const RecipeListScreen({super.key});

  @override
  State<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen> {
  final Box<Recipe> _recipeBox = Hive.box<Recipe>('recipesBox');
  String _searchQuery = '';
  bool _showFavoritesOnly = false;

  void _deleteRecipe(int index, Recipe recipe) {
    _recipeBox.delete(recipe.id); // Видалення по ключу
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Рецепт видалено')));
  }

  void _toggleFavorite(Recipe recipe) {
    recipe.isFavorite = !recipe.isFavorite;
    _recipeBox.put(recipe.id, recipe); // Оновлення (Update)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Кулінарна Книга (Hive)'),
        actions: [
          IconButton(
            icon: Icon(_showFavoritesOnly ? Icons.favorite : Icons.favorite_border),
            onPressed: () => setState(() => _showFavoritesOnly = !_showFavoritesOnly),
            tooltip: 'Показати улюблені',
          )
        ],
      ),
      body: Column(
        children: [
          // Пошук
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Пошук рецептів...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          
          // Список рецептів (Reactive UI)
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: _recipeBox.listenable(),
              builder: (context, Box<Recipe> box, _) {
                // Фільтрація (Пошук + Улюблені)
                var recipes = box.values.where((r) {
                  final matchesSearch = r.name.toLowerCase().contains(_searchQuery);
                  final matchesFav = _showFavoritesOnly ? r.isFavorite : true;
                  return matchesSearch && matchesFav;
                }).toList();

                if (recipes.isEmpty) {
                  return const Center(child: Text('Рецептів не знайдено. Додайте перший!'));
                }

                return ListView.builder(
                  itemCount: recipes.length,
                  itemBuilder: (context, index) {
                    final recipe = recipes[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.shade100,
                          child: Text(recipe.category[0], style: const TextStyle(color: Colors.orange)),
                        ),
                        title: Text(recipe.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${recipe.category} • ${recipe.timeMinutes} хв'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(recipe.isFavorite ? Icons.favorite : Icons.favorite_border, 
                                  color: recipe.isFavorite ? Colors.red : Colors.grey),
                              onPressed: () => _toggleFavorite(recipe),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.grey),
                              onPressed: () => _deleteRecipe(index, recipe),
                            ),
                          ],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => RecipeDetailScreen(recipe: recipe)),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddRecipeScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ==========================================
// 3. ЕКРАН ДОДАВАННЯ РЕЦЕПТУ
// ==========================================
class AddRecipeScreen extends StatefulWidget {
  const AddRecipeScreen({super.key});

  @override
  State<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  final _box = Hive.box<Recipe>('recipesBox');
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final _ingredientsCtrl = TextEditingController();
  final _stepsCtrl = TextEditingController();
  String _selectedCategory = 'Сніданок';

  void _saveRecipe() {
    if (_nameCtrl.text.isEmpty || _timeCtrl.text.isEmpty) return;

    final newRecipe = Recipe(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text,
      description: _descCtrl.text,
      category: _selectedCategory,
      timeMinutes: int.tryParse(_timeCtrl.text) ?? 0,
      ingredients: _ingredientsCtrl.text,
      steps: _stepsCtrl.text,
    );

    _box.put(newRecipe.id, newRecipe); // CREATE
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Новий рецепт')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Назва рецепту')),
            TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Короткий опис')),
            TextField(controller: _timeCtrl, decoration: const InputDecoration(labelText: 'Час приготування (хв)'), keyboardType: TextInputType.number),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              items: ['Сніданок', 'Обід', 'Вечеря', 'Десерт'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _selectedCategory = v!),
              decoration: const InputDecoration(labelText: 'Категорія'),
            ),
            const SizedBox(height: 10),
            TextField(controller: _ingredientsCtrl, decoration: const InputDecoration(labelText: 'Інгредієнти (через кому)'), maxLines: 3),
            TextField(controller: _stepsCtrl, decoration: const InputDecoration(labelText: 'Кроки приготування'), maxLines: 4),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveRecipe,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: const Text('Зберегти рецепт'),
            )
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 4. ЕКРАН ДЕТАЛЕЙ РЕЦЕПТУ
// ==========================================
class RecipeDetailScreen extends StatelessWidget {
  final Recipe recipe;
  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(recipe.name)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text(recipe.description, style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic)),
            const SizedBox(height: 10),
            Chip(label: Text('${recipe.category} • ${recipe.timeMinutes} хвилин', style: const TextStyle(fontWeight: FontWeight.bold))),
            const Divider(height: 30),
            const Text('🛒 Інгредієнти:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(recipe.ingredients.isEmpty ? 'Не вказано' : recipe.ingredients, style: const TextStyle(fontSize: 16)),
            const Divider(height: 30),
            const Text('🍳 Спосіб приготування:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(recipe.steps.isEmpty ? 'Не вказано' : recipe.steps, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}