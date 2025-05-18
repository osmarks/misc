from dataclasses import dataclass
from collections import Counter, defaultdict, deque
import math
from typing import Generator
import scipy.optimize as opt
import numpy as np
import graphviz

@dataclass
class Recipe:
    slots: list[str]
    quantity: int
    processing: bool

short_names = {
    "minecraft:stone": "st",
    "minecraft:redstone": "re",
    "minecraft:glass": "gl",
    "minecraft:glass_pane": "gp",
    "minecraft:gold_ingot": "gi",
    "minecraft:iron_ingot": "ii",
    "minecraft:oak_wood": "ow",
    "minecraft:oak_planks": "op",
    "minecraft:oak_chest": "oc",
    "computercraft:computer": "cc",
    "computercraft:computer_advanced": "ca",
    "computercraft:turtle": "tu",
    "minecraft:birch_wood": "bw",
    "minecraft:birch_planks": "bp",
    "quark:birch_chest": "bc",
    "computercraft:turtle_advanced": "ta",
    "minecraft:gold_block": "gb",
    "minecraft:coal": "co",
    "minecraft:charcoal": "ch",
    "minecraft:gold_ore": "go",
    "minecraft:iron_ore": "io",
    "minecraft:sand": "sa",
    None: "-"
}

short_names_inv = {v: k for k, v in short_names.items()}

recipes = {}

def recipe_short(output, qty, inputs, processing=False):
    recipes[short_names_inv[output]] = Recipe([short_names_inv.get(slot, slot) for slot in inputs.split()], qty, processing)

recipe_short("gp", 16, "gl gl gl gl gl gl")
recipe_short("op", 4, "ow")
recipe_short("oc", 1, "op op op op - op op op op")
recipe_short("cc", 1, "st st st st re st st gp st")
recipe_short("tu", 1, "ii ii ii ii cc ii ii oc ii")
recipe_short("ca", 1, "gi gi gi gi re gi gi gp gi")
recipe_short("ta", 1, "gi gi gi gi ca gi gi oc gi")

@dataclass
class Inventory:
    contents: dict[str, int]

    def __getitem__(self, item):
        return self.contents.get(item, 0)

    def add(self, item, quantity):
        new_inventory = self.contents.copy()
        new_inventory[item] = self.contents.get(item, 0) + quantity
        return Inventory(new_inventory)

    def take(self, item, quantity):
        return self.add(item, -quantity)

class NoRecipe(BaseException):
    pass

def solve(item: str, quantity: int, inventory: Inventory, use_callback, craft_callback) -> Inventory:
    directly_available = min(inventory[item], quantity) # Consume items from storage if available
    if directly_available > 0:
        use_callback(item, directly_available)
    inventory = inventory.take(item, directly_available)
    quantity -= directly_available

    if quantity > 0:
        if recipe := recipes.get(item):
            recipe_runs = math.ceil(quantity / recipe.quantity)
            for citem, cquantity in Counter(recipe.slots).items():
                if citem is not None:
                    inventory = solve(citem, recipe_runs * cquantity, inventory, use_callback, craft_callback) # Recurse into subrecipe
            craft_callback(recipe, item, recipe_runs)
            inventory = inventory.add(item, recipe_runs * recipe.quantity - quantity) # Add spare items to tracked inventory
        else:
            raise NoRecipe(item, quantity) # We need to make this and can't

    return inventory

final = solve("computercraft:turtle", 1, Inventory({
    "minecraft:stone": 100,
    "minecraft:redstone": 1,
    "minecraft:iron_ingot": 10,
    "minecraft:oak_wood": 2,
    "minecraft:glass": 7
}), lambda item, quantity: print(f"Using {quantity} {item}"), lambda recipe, item, runs: print(f"Crafting {runs}x{recipe.quantity} {item}"))

print(final)

def compute_item_graph(recipes_general):
    recipes_forward_graph = defaultdict(set) # edge u→v exists where u is used to craft v
    recipes_backward_graph = defaultdict(set) # edge u→v exists where v's recipe contains u
    for src, recipes in recipes_general.items():
        for recipe in recipes:
            for input in Counter(recipe.slots).keys():
                if input is not None:
                    recipes_forward_graph[input].add(src)
                    recipes_backward_graph[src].add(input)

    return recipes_forward_graph, recipes_backward_graph

def item_graph(recipe_forward_graph, name):
    dot = graphviz.Digraph("items", format="png", body=["\tpad=0.5\n"])
    dot.attr("graph", nodesep="1", ranksep="1")
    nodes = set()

    def mk_node(item):
        if not item in nodes:
            dot.node(item.replace(":", "_"), "", image=f"minecraft_images/{item}.png", imagescale="true", shape="plaintext")
            nodes.add(item)

    for input, outputs in recipe_forward_graph.items():
        mk_node(input)
        for output in outputs:
            dot.edge(input.replace(":", "_"), output.replace(":", "_"))
            mk_node(output)

    dot.render(filename=name)

recipes_general = defaultdict(list)

for src, recipe in recipes.items():
    recipes_general[src].append(recipe)

item_graph(compute_item_graph(recipes_general)[0], "basic")

# Add multiple recipes for things to make the ILP solver work harder.

def recipe_short_extra(output, qty, inputs, processing=False):
    recipes_general[short_names_inv[output]].append(Recipe([short_names_inv.get(slot, slot) for slot in inputs.split()], qty, processing))

recipe_short_extra("bp", 4, "bw")
recipe_short_extra("bc", 1, "bp bp bp bp - bp bp bp bp")
recipe_short_extra("tu", 1, "ii ii ii ii cc ii ii bc ii")
recipe_short_extra("gb", 1, "gi gi gi gi gi gi gi gi gi")
recipe_short("ta", 1, "gi gi gi gi ca gi gi bc gi")
recipe_short_extra("ta", 1, "gi gb gi gi tu gi - gi -")
recipe_short_extra("ta", 1, "gi gb gi gi tu gi - gi -")
for count in [1, 8]:
    recipe_short_extra("gl", count, "ch" + " sa" * count, processing=True)
    recipe_short_extra("gl", count, "co" + " sa" * count, processing=True)
    recipe_short_extra("ii", count, "ch" + " io" * count, processing=True)
    recipe_short_extra("ii", count, "co" + " io" * count, processing=True)
    recipe_short_extra("gi", count, "ch" + " go" * count, processing=True)
    recipe_short_extra("gi", count, "co" + " go" * count, processing=True)
    recipe_short_extra("ch", count, "co" + " ow" * count, processing=True)
    recipe_short_extra("ch", count, "co" + " bw" * count, processing=True)

recipes_forward_graph, recipes_backward_graph = compute_item_graph(recipes_general)

item_graph(recipes_forward_graph, "complex")

def topo_sort_inputs(item: str) -> Generator[str]:
    seen = set()

    # DFS to find root nodes in relevant segment (no incoming edges → no recipes)
    def dfs(item):
        if item in seen or not item: return
        seen.add(item)

        for input in recipes_backward_graph[item]:
            dfs(input)

    dfs(item)
    roots = deque(item for item in seen if len(recipes_general[item]) == 0)

    # Kahn's algorithm (approximately)
    # Count incoming edges
    counts = { item: len(inputs) for item, inputs in recipes_backward_graph.items() if item in seen }

    while roots:
        item = roots.popleft()
        yield item
        for out_edge in recipes_forward_graph[item]:
            # Filter out items not in current operation's subtree
            if (count := counts.get(out_edge)) != None:
                counts[out_edge] -= 1
                # It's now safe to use this item since its dependencies are all in output
                if counts[out_edge] == 0:
                    roots.append(out_edge)

def solve_ilp(item: str, quantity: int, inventory: Inventory, use_callback, craft_callback):
    sequence = list(topo_sort_inputs(item))

    recipe_steps = []

    # Rewrite (involved) recipes as production/consumption numbers.
    items = { sitem: [] for sitem in sequence }

    for item in sequence:
        for recipe in recipes_general[item]:
            step_changes = { sitem: 0 for sitem in sequence }
            for citem, cquantity in Counter(recipe.slots).items():
                if citem is not None:
                    step_changes[citem] = -cquantity
            step_changes[item] = recipe.quantity

            recipe_steps.append((item, recipe))

            for sitem, coef in step_changes.items():
                items[sitem].append(coef)

    objective = np.ones(len(recipe_steps))
    # The amount of each item we produce/consume is linearly dependent on how many times each recipe is executed.
    # This matrix is that linear transform.
    # Solver wants upper bounds so flip signs.
    production_matrix = -np.stack([np.array(coefs) for item, coefs in items.items()])
    # production_matrix @ x is the vector of item consumption, so we upper-bound that with inventory item counts
    # and require that we produce the required output (negative net consumption)
    item_constraint_vector = np.array([ -quantity + inventory[i] if i == item else inventory[i] for i in sequence ])

    soln = opt.linprog(objective, integrality=np.ones_like(objective), A_ub=production_matrix, b_ub=item_constraint_vector)

    match soln.status:
        case 0:
            print("OK")
            # soln.x is now the number of times to execute each recipe_step
            item_consumption = production_matrix @ soln.x
            for item_name, consumption in zip(sequence, item_consumption):
                consumption = int(consumption)
                if consumption > 0:
                    use_callback(item_name, consumption)
                inventory = inventory.take(item_name, consumption)
            for (recipe_output, recipe_spec), execution_count in zip(recipe_steps, soln.x):
                execution_count = int(execution_count)
                if execution_count > 0:
                    craft_callback(recipe_spec, recipe_output, execution_count)
            return inventory
        case 1:
            print("iteration limit reached")
            raise NoRecipe
        case 2:
            print("infeasible")
            raise NoRecipe

print(solve_ilp("computercraft:turtle_advanced", 1, Inventory({
    "minecraft:stone": 100,
    "minecraft:redstone": 1,
    "minecraft:iron_ingot": 10,
    "minecraft:gold_ore": 16,
    "minecraft:oak_wood": 3,
    "minecraft:birch_wood": 8,
    "minecraft:glass": 7,
    "minecraft:coal": 1,
    "minecraft:sand": 16,
}), lambda item, quantity: print(f"Using {quantity} {item}"), lambda recipe, item, runs: print(f"Crafting {runs}x{recipe.quantity} {item}")))
