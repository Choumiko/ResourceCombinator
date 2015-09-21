for _, player in pairs(game.players) do
  player.force.reset_recipes()
  player.force.reset_technologies()

  if player.force.technologies["circuit-network"].researched then
    player.force.recipes["resource-combinator"].enabled = true
  end
end