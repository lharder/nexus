components {
  id: "script"
  component: "/levels/playground/hero/heroworker.script"
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
  "color {\n"
  "  x: 0.0\n"
  "}\n"
  "text: \"Main\"\n"
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
embedded_components {
  id: "collisionobject"
  type: "collisionobject"
  data: "type: COLLISION_OBJECT_TYPE_KINEMATIC\n"
  "mass: 0.0\n"
  "friction: 0.1\n"
  "restitution: 0.5\n"
  "group: \"ship\"\n"
  "mask: \"shot\"\n"
  "embedded_collision_shape {\n"
  "  shapes {\n"
  "    shape_type: TYPE_BOX\n"
  "    position {\n"
  "    }\n"
  "    rotation {\n"
  "    }\n"
  "    index: 0\n"
  "    count: 3\n"
  "  }\n"
  "  shapes {\n"
  "    shape_type: TYPE_BOX\n"
  "    position {\n"
  "      x: -26.0\n"
  "    }\n"
  "    rotation {\n"
  "    }\n"
  "    index: 3\n"
  "    count: 3\n"
  "  }\n"
  "  shapes {\n"
  "    shape_type: TYPE_BOX\n"
  "    position {\n"
  "      x: -4.0\n"
  "    }\n"
  "    rotation {\n"
  "    }\n"
  "    index: 6\n"
  "    count: 3\n"
  "  }\n"
  "  data: 40.0\n"
  "  data: 5.0\n"
  "  data: 10.0\n"
  "  data: 12.5\n"
  "  data: 30.0\n"
  "  data: 10.0\n"
  "  data: 6.0\n"
  "  data: 18.0\n"
  "  data: 10.0\n"
  "}\n"
  ""
}
