components {
  id: "script"
  component: "/levels/playground/shot/explo.script"
}
embedded_components {
  id: "sprite"
  type: "sprite"
  data: "default_animation: \"white\"\n"
  "material: \"/builtins/materials/sprite.material\"\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/levels/playground/explo.tilesource\"\n"
  "}\n"
  ""
  scale {
    x: 2.0
    y: 2.0
    z: 2.0
  }
}
