/// Scoped environment for runtime value bindings.
///
/// Implements lexical scoping via a parent chain. Each scope holds its own
/// bindings and delegates lookups to its parent when a name is not found locally.
/// Parents are shared via `Arc` — cloning an environment is O(current_scope),
/// not O(total_visible_bindings).
use std::collections::HashMap;
use std::sync::Arc;

use crate::interpreter::Value;

/// A scoped environment mapping names to runtime values.
#[derive(Debug, Clone)]
pub struct Environment {
    bindings: HashMap<String, Value>,
    parent: Option<Arc<Environment>>,
}

impl Environment {
    /// Create a new top-level environment with no parent.
    pub fn new() -> Self {
        Self {
            bindings: HashMap::new(),
            parent: None,
        }
    }

    /// Create a child environment that inherits from `parent`.
    pub fn with_parent(parent: Environment) -> Self {
        Self {
            bindings: HashMap::new(),
            parent: Some(Arc::new(parent)),
        }
    }

    /// Create a child environment that inherits from an Arc-shared parent.
    pub fn with_arc_parent(parent: Arc<Environment>) -> Self {
        Self {
            bindings: HashMap::new(),
            parent: Some(parent),
        }
    }

    /// Wrap this environment in an Arc for sharing (e.g., closure capture).
    pub fn capture(&self) -> Arc<Self> {
        Arc::new(self.clone())
    }

    /// Look up a binding by name, searching parent scopes.
    pub fn get(&self, name: &str) -> Option<&Value> {
        self.bindings
            .get(name)
            .or_else(|| self.parent.as_ref().and_then(|p| p.get(name)))
    }

    /// Bind a name to a value in the current scope.
    pub fn set(&mut self, name: &str, value: Value) {
        self.bindings.insert(name.to_string(), value);
    }

    /// Clone this environment for closure capture.
    ///
    /// With Arc-shared parents, this is cheap: only the current scope's bindings
    /// are cloned; parent scopes are shared by reference.
    pub fn clone_flat(&self) -> Self {
        self.clone()
    }
}

impl Default for Environment {
    fn default() -> Self {
        Self::new()
    }
}
