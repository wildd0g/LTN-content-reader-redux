for i, force in pairs(game.forces) do 
  force.reset_recipes()
  force.reset_technologies()
  
  if force.technologies["circuit-network-2"].researched then
    if force.recipes["ltn-provider-reader"] then
      force.recipes["ltn-provider-reader"].enabled= true
    end
    if force.recipes["ltn-requester-reader"] then
      force.recipes["ltn-requester-reader"].enabled = true
    end
    if force.recipes["ltn-delivery-reader"] then
      force.recipes["ltn-delivery-reader"].enabled = true
    end
  else
    if force.recipes["ltn-provider-reader"] then
      force.recipes["ltn-provider-reader"].enabled= false
    end
    if force.recipes["ltn-requester-reader"] then
      force.recipes["ltn-requester-reader"].enabled = false
    end
    if force.recipes["ltn-delivery-reader"] then
      force.recipes["ltn-delivery-reader"].enabled = false
    end
  end
end
