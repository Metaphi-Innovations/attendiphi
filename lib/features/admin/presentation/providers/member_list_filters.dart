/// Sort options for the Members / User Management list.
enum MemberSortOption {
  mostVisitors('Rank (Most Visitors)'),
  nameAsc('Name (A-Z)'),
  nameDesc('Name (Z-A)'),
  newest('Recently Added');

  const MemberSortOption(this.label);
  final String label;
}

/// Status filter for the Members / User Management list.
enum MemberStatusFilter {
  all('All Statuses'),
  active('Active Only'),
  inactive('Inactive Only');

  const MemberStatusFilter(this.label);
  final String label;
}
