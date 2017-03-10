//
//  BoxedTable.swift
//  FileCheck
//
//  Created by Robert Widmann on 3/9/17.
//
//

final class BoxedTable {
  var table : [String:String] = [:]

  init() {}

  subscript(_ i : String) -> String? {
    set {
      self.table[i] = newValue!
    }
    get {
      return self.table[i]
    }
  }
}
