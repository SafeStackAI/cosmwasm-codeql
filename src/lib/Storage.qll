/**
 * Modeling of CosmWasm storage operations (cw-storage-plus).
 *
 * Detects read/write/delete operations on Item, Map, and IndexedMap
 * storage types via method call name matching.
 */

import rust

/**
 * A method call on a CosmWasm storage type (Item, Map, IndexedMap).
 * Matches storage operations by method name.
 */
class StorageAccess extends MethodCallExpr {
  StorageAccess() {
    this.getIdentifier().toString() in [
        "save", "load", "may_load", "update", "remove"
      ]
  }

  /** Gets the method name of this storage operation. */
  string getMethodName() { result = this.getIdentifier().toString() }
}

/**
 * A storage write operation: `.save()` or `.update()`.
 * These modify contract state.
 */
class StorageWrite extends StorageAccess {
  StorageWrite() {
    this.getMethodName() in ["save", "update"]
  }
}

/**
 * A storage read operation: `.load()` or `.may_load()`.
 */
class StorageRead extends StorageAccess {
  StorageRead() {
    this.getMethodName() in ["load", "may_load"]
  }
}

/**
 * A storage delete operation: `.remove()`.
 */
class StorageDelete extends StorageAccess {
  StorageDelete() {
    this.getMethodName() = "remove"
  }
}

/**
 * Holds if function `f` contains a storage write operation.
 */
predicate hasStorageWrite(Function f) {
  exists(StorageWrite w |
    w.getEnclosingCallable() = f
  )
}

/**
 * Holds if function `f` contains a storage read operation.
 */
predicate hasStorageRead(Function f) {
  exists(StorageRead r |
    r.getEnclosingCallable() = f
  )
}

/**
 * A call expression that constructs a storage type.
 * Matches `Item::new("key")` and `Map::new("key")` patterns.
 * Note: CodeQL Rust extractor elides paths as `...::new`.
 * We identify storage declarations by: static const context + `...::new` + string literal arg.
 */
class StorageDeclaration extends CallExpr {
  StorageDeclaration() {
    this.getFunction().toString().matches("%::new%") and
    // Must have a string literal as first argument (the storage key)
    exists(LiteralExpr lit |
      lit = this.getArgList().getArg(0) and
      lit.toString().matches("\"%\"")
    ) and
    // Must be in a const/static context (top-level storage declarations)
    not exists(Function f | this.getEnclosingCallable() = f and f.getNumberOfParams() > 0)
  }
}
