/// Matches the visible category order; creator is a route after For You.
enum MediaFeedTab {
  other, sermon, dua, recitation, following, forYou;

  MediaFeedTab? get next => index + 1 < values.length ? values[index + 1] : null;
  MediaFeedTab? get previous => index > 0 ? values[index - 1] : null;
}
