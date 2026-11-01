# Jackcess's optional expression evaluator references Java's scripting API,
# which Android does not provide. Songbook import reads table values directly
# and does not use DBEvalContext or javax.script.
-dontwarn javax.script.Bindings
-dontwarn javax.script.SimpleBindings
