def get_world_combination(target_amount, worlds):
    for world in worlds:
        world['total_amount'] = world['amounts']["1796"] + (100 * world['amounts']["7188"])
        world['amount'] = 0  # Initialize the amount to be taken from each world
    
    sorted_worlds = sorted(worlds, key=lambda x: x['total_amount'], reverse=True)
    
    for world in sorted_worlds:
        if world['total_amount'] >= target_amount:
            world['amount'] = target_amount
            return [world]
    
    current_total = 0
    selected_worlds = []
    
    for world in sorted_worlds:
        if current_total >= target_amount:
            break
        amount_needed = target_amount - current_total
        amount_to_take = min(world['total_amount'], amount_needed)
        world['amount'] = amount_to_take
        current_total += amount_to_take
        selected_worlds.append(world)
    
    if current_total >= target_amount:
        return selected_worlds
    
    print("Error: Target amount cannot be achieved with the available worlds.")
    return []

# Example usage:
worlds = [
    {"world": "A", "id": "1", "amounts": {"1796": 10, "7188": 2}},
    {"world": "B", "id": "2", "amounts": {"1796": 20, "7188": 1}},
    {"world": "C", "id": "3", "amounts": {"1796": 15, "7188": 0}}
]

target_amount = 270

result = get_world_combination(target_amount, worlds)
print(result)
