import 'catalog_models.dart';

/// Pure helpers over the category tree — kept off the widgets so the
/// merchandising rules can be unit-tested without pumping a screen.

/// Where a department lands in a pet's board.
///
/// The server sorts departments alphabetically, which puts "التنظيف" above
/// "طعام" — the opposite of how a pet store is shopped. Food is the reason
/// most customers open the app; treats and general supplies follow; litter,
/// cleaning and bundles trail. Anything unrecognised keeps its server order
/// after the known groups, so a new department is never hidden.
int departmentRank(String name) {
  final n = name.toLowerCase();
  const groups = <(List<String>, int)>[
    (['طعام', 'food'], 0),
    (['مكاف', 'فيتامين', 'treat', 'vitamin'], 1),
    // Litter before general supplies: "مستلزمات الرمل" is a litter aisle.
    (['رمل', 'litter'], 4),
    (['مستلزمات', 'suppl', 'accessor'], 2),
    (['صحة', 'health'], 3),
    (['تنظيف', 'clean', 'تدريب', 'train'], 5),
    (['بكج', 'bundle', 'pack'], 6),
  ];
  for (final (keys, rank) in groups) {
    if (keys.any(n.contains)) return rank;
  }
  return 7;
}

/// A pet's departments in shopping order. Stable, so two departments in the
/// same group keep the server's alphabetical order between them.
List<CategoryNode> orderedDepartments(List<CategoryNode> children) {
  final indexed = children.indexed.toList()
    ..sort((a, b) {
      final byRank = departmentRank(
        a.$2.name,
      ).compareTo(departmentRank(b.$2.name));
      return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
    });
  return [for (final (_, node) in indexed) node];
}

/// How many departments lead the board as full-width cards.
///
/// The first one or two are the aisles nearly everyone came for, so they get
/// the wide card. The count is chosen so the two-column grid underneath is
/// never left with a lonely half-row: an even remainder or nothing at all.
int wideDepartmentCount(int total) {
  if (total <= 2) return total;
  return (total - 1).isEven ? 1 : 2;
}

/// A department's place in the tree: the pet it belongs to, and itself — or
/// null for `current` when [slug] *is* the pet.
typedef CategoryPlace = ({CategoryNode root, CategoryNode? current});

/// Finds [slug] among the pets and their departments.
///
/// Slugs travel percent-encoded (Arabic terms are stored that way), and a
/// deep link may hand back the decoded form — both spellings match.
CategoryPlace? locateCategory(List<CategoryNode> roots, String? slug) {
  if (slug == null || slug.isEmpty) return null;
  final wanted = _slugForms(slug);
  for (final root in roots) {
    if (_slugForms(root.slug).intersection(wanted).isNotEmpty) {
      return (root: root, current: null);
    }
    for (final child in root.children) {
      if (_slugForms(child.slug).intersection(wanted).isNotEmpty) {
        return (root: root, current: child);
      }
    }
  }
  return null;
}

Set<String> _slugForms(String slug) {
  final forms = <String>{slug, slug.toLowerCase()};
  try {
    forms.add(Uri.decodeComponent(slug));
  } on ArgumentError {
    // Not percent-encoded; the raw form is already in the set.
  }
  return forms;
}
