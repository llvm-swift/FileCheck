/// Determine the edit distance between two sequences.
///
/// - parameter fa: The first sequence to compare.
/// - parameter ta: The second sequence to compare.
///
/// - returns: the minimum number of element insertions, removals, or
///   replacements needed to transform one of the given sequences into the
///   other. If zero, the sequences are identical.
func editDistance(from fa : Substring, to ta : Substring) -> Int {
  guard !fa.isEmpty else {
    return ta.count
  }

  guard !ta.isEmpty else {
    return fa.count
  }

  // The algorithm implemented below is the "classic"
  // dynamic-programming algorithm for computing the Levenshtein
  // distance, which is described here:
  //
  //   http://en.wikipedia.org/wiki/Levenshtein_distance
  //
  // Although the algorithm is typically described using an m x n
  // array, only one row plus one element are used at a time, so this
  // implementation just keeps one vector for the row.  To update one entry,
  // only the entries to the left, top, and top-left are needed.  The left
  // entry is in `row[x-1]`, the top entry is what's in `row[x]` from the last
  // iteration, and the top-left entry is stored in Previous.
  var pre = [Int](0..<(ta.count + 1))
  var cur = [Int](repeating: 0, count: ta.count + 1)

  for (i, ca) in fa.enumerated() {
    cur[0] = i + 1;
    for (j, cb) in ta.enumerated() {
      cur[j + 1] = min(
        // deletion
        pre[j + 1] + 1, min(
          // insertion
          cur[j] + 1,
          // match or substitution
          pre[j] + (ca == cb ? 0 : 1)))
    }
    swap(&cur, &pre)
  }
  return pre[ta.count]
}
