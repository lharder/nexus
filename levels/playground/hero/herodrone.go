components {
  id: "script"
  component: "/levels/playground/hero/herodrone.script"
}
embedded_components {
  id: "sprite"
  type: "sprite"
  data: "default_animation: \"ship\"\n"
  "material: \"/builtins/materials/sprite.material\"\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/levels/playground/playground.atlas\"\n"
  "}\n"
  ""
  scale {
    x: 0.3
    y: 0.2
  }
}
embedded_components {
  id: "caption"
  type: "label"
  data: "size {\n"
  "  x: 128.0\n"
  "  y: 32.0\n"
  "}\n"
  "text: \"Drone\"\n"
  "font: \"/builtins/fonts/default.font\"\n"
  "material: \"/builtins/fonts/label-df.material\"\n"
  ""
  position {
    x: -80.0
  }
  rotation {
    z: 0.70710677
    w: -0.70710677
  }
}
