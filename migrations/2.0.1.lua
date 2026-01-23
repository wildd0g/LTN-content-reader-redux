for i, force in pairs(game.forces) do 
  force.reset_recipes()
  force.reset_technologies()
  
  if force.technologies["circuit-network-2"].researched then
    if force.recipes["lltn-content-reader"] then
      force.recipes["ltn-content-reader"].enabled= true
    end
  else
    if force.recipes["ltn-content-reader"] then
      force.recipes["ltn-content-reader"].enabled= false
    end
  end
end
