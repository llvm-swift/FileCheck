/// Determine the edit distance between two sequences.
///
/// - parameter fa: The first sequence to compare.
/// - parameter ta: The second sequence to compare.
/// - parameter allowReplacements: Whether to allow element replacements (change one
///   element into another) as a single operation, rather than as two operations
///   (an insertion and a removal).
/// - parameter maxEditDistance: If non-zero, the maximum edit distance that this
///   routine is allowed to compute. If the edit distance will exceed that
///   maximum, returns \c MaxEditDistance+1.
///
/// - returns: the minimum number of element insertions, removals, or (if
///   `allowReplacements` is `true`) replacements needed to transform one of
///   the given sequences into the other. If zero, the sequences are identical.
func editDistance<T: Equatable>(from fa : [T], to ta : [T], allowReplacements : Bool = true, maxEditDistance : Int = 0) -> Int {
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
  let m = fa.count
  let n = ta.count

  var row = [Int](1...(n+1))

  for y in 1...m {
    row[0] = y
    var bestThisRow = row[0]

    var previous = y - 1
    for x in 1...n {
      let oldRow = row[x]
      if allowReplacements {
        row[x] = min(
          previous + (fa[y - 1] == ta[x - 1] ? 0 : 1),
          min(row[x - 1], row[x]) + 1
        )
      } else {
        if fa[y-1] == ta[x-1] {
          row[x] = previous
        } else {
          row[x] = min(row[x-1], row[x]) + 1
        }
      }
      previous = oldRow
      bestThisRow = min(bestThisRow, row[x])
    }

    if maxEditDistance != 0 && bestThisRow > maxEditDistance {
      return maxEditDistance + 1
    }
  }

  return row[n]
}
