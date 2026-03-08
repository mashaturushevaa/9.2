# Практична робота 9.2: Робота з Hive у Flutter
## Варіант: 4 (Recipe Book з Hive)

## Technology: Hive (NoSQL)
У цій роботі використано швидку NoSQL базу даних Hive. Для уникнення помилок кодогенерації (`build_runner`) та забезпечення стабільної роботи на всіх платформах (зокрема Windows/Web), `TypeAdapter` для моделі був написаний вручну.

## Database Schema / Models (HiveTypes)
Створено модель `Recipe` (typeId: 0), яка зберігається у `recipesBox`:
- `id` (String) - унікальний ідентифікатор
- `name` (String) - назва
- `description` (String) - опис
- `category` (String) - категорія (Сніданок/Обід/тощо)
- `timeMinutes` (int) - час
- `isFavorite` (bool) - статус улюбленого
- `ingredients` (String)
- `steps` (String)

## Реалізовані функції
- [x] **CRUD operations:** Додавання рецептів, їх відображення, оновлення статусу (улюблене), видалення.
- [x] **Complex queries / Фільтрація:** Реалізовано пошук за назвою та фільтр за статусом "Улюблене".
- [x] **Reactive UI:** Використано `ValueListenableBuilder` для миттєвого оновлення інтерфейсу при змінах у БД.

## Складні запити / Алгоритми
Оскільки Hive є NoSQL базою, фільтрація та пошук відбуваються через методи колекцій Dart (аналог WHERE в SQL):
```dart
var recipes = box.values.where((r) {
  final matchesSearch = r.name.toLowerCase().contains(_searchQuery);
  final matchesFav = _showFavoritesOnly ? r.isFavorite : true;
  return matchesSearch && matchesFav;
}).toList();
