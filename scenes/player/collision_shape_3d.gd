extends CollisionShape3D

# Assuming you have imported the collision mesh
var collision_mesh = load("res://assets/player/model/collision_character_ski.obj").instantiate()

# Create a MeshShape3D from the mesh
var mesh_shape = MeshShape3D.new()
mesh_shape.mesh = collision_mesh.mesh

# Create a CollisionShape3D node
var collision_shape = CollisionShape3D.new()
collision_shape.shape = mesh_shape

# Add the collision shape to your scene
add_child(collision_shape)