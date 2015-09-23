for _, player in pairs(game.players) do
  player.force.reset_recipes()
  player.force.reset_technologies()
  player.force.recipes["resource-combinator"].enabled = false
  if player.force.technologies["circuit-network"].researched then
    player.force.recipes["resource-combinator-proxy"].enabled = true
  end
end