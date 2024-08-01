components {
  id: "script"
  component: "/levels/playground/shot/shot.script"
}
embedded_components {
  id: "sprite"
  type: "sprite"
  data: "default_animation: \"laser\"\n"
  "material: \"/builtins/materials/sprite.material\"\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/levels/playground/playground.atlas\"\n"
  "}\n"
  ""
  scale {
    x: 0.3
    y: 0.3
  }
}