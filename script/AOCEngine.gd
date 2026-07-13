extends Node

var num_ants = 10  # Número de formigas
var alpha = 1.0    # Importância do feromônio
var beta = 2.0     # Importância da heurística (distância)
var evaporation_rate = 0.5
var q = 100.0      # Intensidade do depósito de feromônio

var cities_positions = []
var dist_matrix = []
var pheromone_matrix = []
var num_cities = 0

signal logic_updated(pheromones, ants_tours)

# Função de inicialização
# Define o mapa, calcula a distância e cria a matriz de
# feromônios
func setup(positions: Array):
	cities_positions = positions
	num_cities = positions.size()
	
	dist_matrix = []
	pheromone_matrix = []
	for i in range(num_cities):
		dist_matrix.append([])
		pheromone_matrix.append([])
		for j in range(num_cities):
			var d = positions[i].distance_to(positions[j])
			dist_matrix[i].append(d if d > 0 else 0.0001)
			pheromone_matrix[i].append(1.0) # Valor inicial de feromônio

# Orquestra 3 etapas:
#		As formiga constroem o caminho
#		Feromônio atualizado com base no desempenho
#		Envia os dados para o visual pelo sinal
func run_iteration():
	var all_tours = []
	
	for _a in range(num_ants):
		var tour = construct_tour()
		all_tours.append(tour)
		
	update_pheromones(all_tours)
	
	emit_signal("logic_updated", pheromone_matrix, all_tours)

# Cada formiga decide seu destino
# Início em uma cidade aleatória:
#		Enquanto não visitarem todas as cidades -> 
#		chama a lógica de seleção para o novo destino
func construct_tour() -> Array:
	var tour = [randi() % num_cities]
	var visited = {tour[0]: true}
	
	while tour.size() < num_cities:
		var current = tour.back()
		var next_city = select_next_city(current, visited)
		tour.append(next_city)
		visited[next_city] = true
		
	tour.append(tour[0]) 
	return tour

# Parte matemática utilizando a formula probabilística
# 	Feromônio (alpha) = O quanto aquele caminho foi usado anteriormente
#	Heurística (beta) =  O inverso da distância (caminhos mais curtos são mais atraentes).
# Garante que as formigas prefiram caminhos curtos e com feromonios
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
	
	var r = randf() * sum_probs
	var cumulative = 0.0
	for i in range(probabilities.size()):
		cumulative += probabilities[i]
		if r <= cumulative:
			return i
	return 0

# Aplicando a evaporação -> caminhos ruins perdem relevância com o tempo
# Deposita mais feromonios nas rotas percorridas, premiando caminhos que gerem
# rotas menores
func update_pheromones(all_tours: Array):
	# Evaporação
	for i in range(num_cities):
		for j in range(num_cities):
			pheromone_matrix[i][j] *= (1.0 - evaporation_rate)
	
	for tour in all_tours:
		var tour_dist = calculate_tour_distance(tour)
		for i in range(tour.size() - 1):
			var from = tour[i]
			var to = tour[i+1]
			pheromone_matrix[from][to] += q / tour_dist
			pheromone_matrix[to][from] += q / tour_dist
			
func calculate_tour_distance(tour: Array) -> float:
	var d = 0.0
	for i in range(tour.size() - 1):
		d += dist_matrix[tour[i]][tour[i+1]]
	return d
