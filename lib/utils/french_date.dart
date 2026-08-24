const _joursSemaine = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
const _moisAnnee = [
  'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
  'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
];

String formatFrenchDate(DateTime date) {
  return '${_joursSemaine[date.weekday - 1]} ${date.day} ${_moisAnnee[date.month - 1]} ${date.year}';
}
