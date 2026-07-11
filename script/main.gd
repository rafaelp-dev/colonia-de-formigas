extends Node2D

# Referências aos nós
@onready var aco_engine = $ACOEngine
@onready var city_container = $CityContainer
@onready var line_container = $LineContainer
@onready var ant_container = $AntContainer

# Preloads das cenas visuais
var city_scene = preload("res://scenes/city.tscn")
var ant_scene = preload("res://scenes/ant.tscn")

# Configurações de execução
var is_running = false
var iteration_delay = 0.5 
var timer = 0.0

# Variáveis do Critério de Parada e Resultados
var current_iteration = 0
const MAX_ITERATIONS = 100 # Critério de parada por limite de iterações
var best_distance_global = INF
var consecutive_no_improvement = 0
const STAGNATION_LIMIT = 20 # Critério de parada por estagnação

var visual_lines = {}
var cost_labels = {}
var ant_tweens = {}

# Elementos de UI criados dinamicamente via código para facilitar
var ui_best_cost_label: Label
var ui_status_label: Label

func _ready():
	# 1. Configurar Labels de Resultado na Interface
	setup_result_ui()
	
	# 2. Definir posições das cidades SEM SOBREPOSIÇÃO
	var positions = []
	var screen_size = get_viewport_rect().size
	var num_cities_to_create = 10
	var min_distance_between_cities = 120.0 
	
	while positions.size() < num_cities_to_create:
		var pos = Vector2(randf_range(100, screen_size.x - 100), randf_range(100, screen_size.y - 100))
		
		var too_close = false
		for existing_pos in positions:
			if pos.distance_to(existing_pos) < min_distance_between_cities:
				too_close = true
				break
				
		if not too_close:
			positions.append(pos)
	
	setup_visual_cities(positions)
	setup_visual_lines(positions)
	setup_visual_ants()

	aco_engine.setup(positions)
	aco_engine.logic_updated.connect(_on_aco_logic_updated)

func _process(delta):
	if is_running:
		timer += delta
		if timer >= iteration_delay:
			current_iteration += 1
			aco_engine.run_iteration() 
			timer = 0.0

func setup_result_ui():
	# Cria um container no canto superior esquerdo para exibir os resultados
	var panel = PanelContainer.new()
	panel.position = Vector2(20, 20)
	panel.custom_minimum_size = Vector2(250, 80)
	add_child(panel)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	ui_status_label = Label.new()
	ui_status_label.text = "Status: Aguardando..."
	vbox.add_child(ui_status_label)
	
	ui_best_cost_label = Label.new()
	ui_best_cost_label.text = "Melhor Distância: -"
	ui_best_cost_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(ui_best_cost_label)

# --- FUNÇÕES DE INTERFACE ---

func _on_btn_start_pressed():
	if current_iteration >= MAX_ITERATIONS or ui_status_label.text.contains("CONVERGIU"):
		# Reinicia contadores se o usuário quiser rodar de novo
		current_iteration = 0
		consecutive_no_improvement = 0
		best_distance_global = INF
	is_running = true
	ui_status_label.text = "Status: Executando (Iteração %d)" % current_iteration

func _on_btn_pause_pressed():
	is_running = false
	ui_status_label.text = "Status: Pausado"

@onready var label: Label = $CanvasLayer/Control/settings/VBoxContainer/velocity/HBoxContainer2/Label
func _on_speed_slider_value_changed(value):
	label.text = str(value)
	iteration_delay = value

# --- PONTE ENTRE LÓGICA E VISUAL ---

func _on_aco_logic_updated(pheromones, tours):
	# 1. Encontrar e atualizar o melhor custo desta iteração
	check_best_solution(tours)
	
	# 2. Atualizar elementos visuais
	update_pheromone_visuals(pheromones)
	animate_ants(tours)
	
	# 3. Validar se atingiu critérios de parada
	check_stopping_criteria()

func check_best_solution(tours: Array):
	var improved = false
	ui_status_label.text = "Status: Executando (Iteração %d/%d)" % [current_iteration, MAX_ITERATIONS]
	
	for tour in tours:
		var dist = aco_engine.calculate_tour_distance(tour)
		if dist < best_distance_global:
			best_distance_global = dist
			improved = true
			consecutive_no_improvement = 0
			ui_best_cost_label.text = "Melhor Distância: %d (Opção Ótima!)" % int(best_distance_global)
			ui_best_cost_label.modulate = Color(1.0, 0.85, 0.0) # Texto Dourado
			
	if not improved:
		consecutive_no_improvement += 1

func check_stopping_criteria():
	# Critério 1: Limite máximo de Iterações atingido
	if current_iteration >= MAX_ITERATIONS:
		stop_simulation("CONVERGIU (Limite de Iterações)")
		
	# Critério 2: Estagnação (A solução não melhora há muitas gerações)
	elif consecutive_no_improvement >= STAGNATION_LIMIT:
		stop_simulation("CONVERGIU (Estagnação da Solução)")

func stop_simulation(reason: String):
	is_running = false
	ui_status_label.text = "Status: %s" % reason
	# Dá um efeito de congelamento visual nas formigas
	for a in ant_tweens.keys():
		if ant_tweens[a] is Tween:
			ant_tweens[a].kill()

# --- IMPLEMENTAÇÃO VISUAL ---

func setup_visual_cities(positions):
	for p in positions:
		var city = city_scene.instantiate()
		city.position = p
		city_container.add_child(city)

func setup_visual_lines(positions):
	var n = positions.size()
	for i in range(n):
		for j in range(i + 1, n):
			var pos_i = positions[i]
			var pos_j = positions[j]
			var key = str(i) + "_" + str(j)
			
			var line = Line2D.new()
			line.width = 2.0
			line.default_color = Color(0.0, 0.7, 0.9, 0.15) 
			line.add_point(pos_i)
			line.add_point(pos_j)
			line_container.add_child(line)
			visual_lines[key] = line
			
			var lbl = Label.new()
			var distance = pos_i.distance_to(pos_j)
			lbl.text = str(int(distance))
			
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 11)
			lbl.modulate = Color(1, 1, 1, 0.05) 
			
			var mid_point = (pos_i + pos_j) / 2.0
			lbl.position = mid_point - Vector2(25, 10)
			lbl.custom_minimum_size = Vector2(50, 20)
			
			line_container.add_child(lbl)
			cost_labels[key] = lbl

func setup_visual_ants():
	for i in range(aco_engine.num_ants):
		var ant = ant_scene.instantiate()
		ant_container.add_child(ant)

func update_pheromone_visuals(pheromones):
	var n = pheromones.size()
	
	var max_pheromone = 0.0001 
	for i in range(n):
		for j in range(i + 1, n):
			var current_value = pheromones[i][j] + pheromones[j][i]
			if current_value > max_pheromone:
				max_pheromone = current_value

	for i in range(n):
		for j in range(i + 1, n):
			var p_value = pheromones[i][j] + pheromones[j][i]
			var key = str(i) + "_" + str(j)
			
			if visual_lines.has(key):
				var line = visual_lines[key]
				var lbl = cost_labels[key]
				
				var relative_strength = p_value / max_pheromone
				
				if relative_strength > 0.4:
					line.width = lerp(2.0, 8.0, relative_strength)
					line.modulate.a = lerp(0.3, 1.0, relative_strength)
					lbl.modulate = Color(1.0, 1.0, 1.0, lerp(0.4, 1.0, relative_strength))
					
					if relative_strength > 0.85:
						line.default_color = Color(1.0, 0.85, 0.0, 1.0) 
						lbl.modulate = Color(1.0, 0.85, 0.0, 1.0)
					else:
						line.default_color = Color(0.0, 1.0, 0.4, 1.0) 
				else:
					line.default_color = Color(0.0, 0.7, 0.9, 0.5)
					line.width = 1.5
					lbl.modulate = Color(1, 1, 1, 0.2)

func animate_ants(tours):
	var ants = ant_container.get_children()
	
	for a in range(tours.size()):
		if a >= ants.size(): break
		
		var ant = ants[a]
		var tour = tours[a]
		
		if ant_tweens.has(a) and ant_tweens[a] is Tween:
			ant_tweens[a].kill()
			
		var tween = create_tween()
		ant_tweens[a] = tween
		
		ant.position = aco_engine.cities_positions[tour[0]]
		
		for i in range(1, tour.size()):
			var next_city_pos = aco_engine.cities_positions[tour[i]]
			var travel_time = iteration_delay / tour.size()
			tween.tween_property(ant, "position", next_city_pos, travel_time)
