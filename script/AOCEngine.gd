extends Node

# Configurações do Algoritmo
var num_ants = 10
var alpha = 1.0    # Importância do feromônio
var beta = 2.0     # Importância da heurística (distância)
var evaporation_rate = 0.5
var q = 100.0      # Intensidade do depósito de feromônio

var cities_positions = [] # Array de Vector2
var dist_matrix = []
var pheromone_matrix = []
var num_cities = 0

# Sinal que comunica o estado atual para o visual (o seu colega)
signal logic_updated(pheromones, ants_tours)

func setup(positions: Array):
	cities_positions = positions
	num_cities = positions.size()
	
	# Inicializar matrizes
	dist_matrix = []
	pheromone_matrix = []
	for i in range(num_cities):
		dist_matrix.append([])
		pheromone_matrix.append([])
		for j in range(num_cities):
			var d = positions[i].distance_to(positions[j])
			dist_matrix[i].append(d if d > 0 else 0.0001)
			pheromone_matrix[i].append(1.0) # Valor inicial de feromônio

func run_iteration():
	var all_tours = []
	
	for _a in range(num_ants):
		var tour = construct_tour()
		all_tours.append(tour)
		
	update_pheromones(all_tours)
	
	# Emite os dados para o seu colega desenhar
	emit_signal("logic_updated", pheromone_matrix, all_tours)

func construct_tour() -> Array:
	var tour = [randi() % num_cities]
	var visited = {tour[0]: true}
	
	while tour.size() < num_cities:
		var current = tour.back()
		var next_city = select_next_city(current, visited)
		tour.append(next_city)
		visited[next_city] = true
		
	# ADICIONE ISTO: Faz a formiga retornar à cidade de origem
	tour.append(tour[0]) 
	return tour

func select_next_city(current: int, visited: Dictionary) -> int:
	var probabilities = []
	var sum_probs = 0.0
	
	for i in range(num_cities):
		if visited.has(i):
			probabilities.append(0.0)
		else:
			# Fórmula: (Feromônio^alpha) * (1/distância^beta)
			var pheromone = pow(pheromone_matrix[current][i], alpha)
			var heuristic = pow(1.0 / dist_matrix[current][i], beta)
			var prob = pheromone * heuristic
			probabilities.append(prob)
			sum_probs += prob
	
	# Roleta russa para escolha
	var r = randf() * sum_probs
	var cumulative = 0.0
	for i in range(probabilities.size()):
		cumulative += probabilities[i]
		if r <= cumulative:
			return i
	return 0 # Fallback

func update_pheromones(all_tours: Array):
	# Evaporação
	for i in range(num_cities):
		for j in range(num_cities):
			pheromone_matrix[i][j] *= (1.0 - evaporation_rate)
	
	# Depósito
	for tour in all_tours:
		var tour_dist = calculate_tour_distance(tour)
		for i in range(tour.size() - 1):
			var from = tour[i]
			var to = tour[i+1]
			# Deposite nos dois sentidos do grafo não-direcionado
			pheromone_matrix[from][to] += q / tour_dist
			pheromone_matrix[to][from] += q / tour_dist
			
func calculate_tour_distance(tour: Array) -> float:
	var d = 0.0
	for i in range(tour.size() - 1):
		d += dist_matrix[tour[i]][tour[i+1]]
	return d
