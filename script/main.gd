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

var total_execution_time = 0.0
var time_of_best_solution = 0.0
var ui_time_label: Label

# Variáveis do Critério de Parada e Resultados
var current_iteration = 0
var best_distance_global = INF
var consecutive_no_improvement = 0
const STAGNATION_LIMIT = 20 

var visual_lines = {}
var cost_labels = {}
var ant_tweens = {}

# Elementos de UI criados dinamicamente via código para facilitar
var ui_best_cost_label: Label
var ui_status_label: Label

func _ready():
	# 1. Configurar Labels de Resultado na Interface
	setup_result_ui()
	
	# 2. CONECTAR O SINAL DA LÓGICA (O elo perdido!)
	if aco_engine.has_signal("logic_updated"):
		aco_engine.logic_updated.connect(_on_aco_logic_updated)
	
	# 3. Iniciar o primeiro cenário/grafo
	generate_new_simulation()
func _process(delta):
	if is_running:
		total_execution_time += delta # Soma o tempo real
		
		# ATUALIZA O RELÓGIO NA TELA A CADA FRAME
		ui_time_label.text = "Tempo Total: %.2fs | Melhor em: %.2fs" % [total_execution_time, time_of_best_solution]
		
		timer += delta
		if timer >= iteration_delay:
			current_iteration += 1
			ui_status_label.text = "Status: Executando (Iteração %d)" % current_iteration
			aco_engine.run_iteration() 
			timer = 0.0

func setup_result_ui():
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
	
	# --- TIMER ADICIONADO NO MESMO PAINEL ---
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 5) # Dá um pequeno espaço visual
	vbox.add_child(spacer)
	
	ui_time_label = Label.new()
	ui_time_label.text = "Tempo Total: 0.00s | Melhor em: 0.00s" # <-- Novo Formato
	ui_time_label.add_theme_font_size_override("font_size", 14)
	ui_time_label.modulate = Color(0.7, 0.9, 1.0)
	vbox.add_child(ui_time_label)

# --- FUNÇÃO CENTRAL DE GERAÇÃO/RESET ---

func generate_new_simulation():
	# 1. Interromper execuções e Tweens ativos
	is_running = false
	timer = 0.0
	for a in ant_tweens.keys():
		if ant_tweens[a] is Tween:
			ant_tweens[a].kill()
	
	# 2. LIMPEZA IMEDIATA: Usamos .free() em vez de .queue_free() para limpar a árvore na hora!
	for child in city_container.get_children(): 
		child.free()
	for child in line_container.get_children(): 
		child.free()
	for child in ant_container.get_children(): 
		child.free()
	
	# 3. Resetar dicionários e variáveis de estado
	visual_lines.clear()
	cost_labels.clear()
	ant_tweens.clear()
	
	current_iteration = 0
	consecutive_no_improvement = 0
	best_distance_global = INF
	
	ui_status_label.text = "Status: Novo Grafo Gerado"
	ui_best_cost_label.text = "Melhor Distância: -"
	ui_best_cost_label.modulate = Color(1, 1, 1, 1)
	
	total_execution_time = 0.0
	time_of_best_solution = 0.0
	ui_time_label.text = "Tempo Total: 0.00s | Melhor em: 0.00s"
	# 4. Sorteia novas posições de cidades sem sobreposição
	var positions = []
	var screen_size = get_viewport_rect().size
	var num_cities_to_create = 10 # Agora pode colocar 20, 50...
	
	# MÁGICA 1: Se for mais de 10 cidades, a distância mínima cai drasticamente!
	var min_distance_between_cities = 200.0 if num_cities_to_create <= 10 else 40.0 
	
	# MÁGICA 2: Trava de segurança. Se tentar 2000 vezes e não achar espaço, ele para de tentar.
	var max_attempts = 2000 
	var attempts = 0
	
	while positions.size() < num_cities_to_create and attempts < max_attempts:
		attempts += 1
		# Diminuí a margem da borda de 100 para 50 para dar mais espaço útil
		var pos = Vector2(randf_range(50, screen_size.x - 50), randf_range(50, screen_size.y - 50))
		var too_close = false
		
		for existing_pos in positions:
			if pos.distance_to(existing_pos) < min_distance_between_cities:
				too_close = true
				break
				
		if not too_close:
			positions.append(pos)
			attempts = 0 # Reseta as tentativas porque conseguiu achar um lugar!
			
	if attempts >= max_attempts:
		print("Aviso: Tela cheia! Só consegui colocar %d cidades." % positions.size())
	
	# 5. Configurar PRIMEIRO a lógica e DEPOIS o visual para os dados estarem prontos
	aco_engine.setup(positions)
	
	setup_visual_cities(positions)
	setup_visual_lines(positions)
	setup_visual_ants()

# --- FUNÇÕES DE INTERFACE ---
func _on_btn_start_pressed():
	print("Botão START clicado!")
	
	# Se a simulação já terminou por estagnação, queremos apenas "dar um empurrãozinho"
	# para continuar no mesmo mapa. Mantemos o tempo, a iteração e a melhor distância!
	if ui_status_label.text.contains("CONVERGIU"):
		consecutive_no_improvement = 0
		# Removido: reset de best_distance_global, current_iteration e total_execution_time
	
	is_running = true
	
	# Status limpo, sem o MAX_ITERATIONS
	ui_status_label.text = "Status: Executando (Iteração %d)" % current_iteration
	
	# Força a primeira execução imediata sem esperar o timer do _process
	if current_iteration == 0:
		current_iteration = 1
		aco_engine.run_iteration()
	
func _on_btn_pause_pressed():
	is_running = false
	ui_status_label.text = "Status: Pausado"

@onready var label: Label = $CanvasLayer/Control/settings/VBoxContainer/velocity/HBoxContainer2/Label
func _on_speed_slider_value_changed(value):
	label.text = str(value)
	iteration_delay = value

# --- PONTE ENTRE LÓGICA E VISUAL ---

func _on_aco_logic_updated(pheromones, tours):
	check_best_solution(tours)
	update_pheromone_visuals(pheromones)
	animate_ants(tours)
	check_stopping_criteria()

func check_best_solution(tours: Array):
	var improved = false
	ui_status_label.text = "Status: Executando (Iteração %d)" % current_iteration
	
	for tour in tours:
		var dist = aco_engine.calculate_tour_distance(tour)
		if dist < best_distance_global:
			best_distance_global = dist
			improved = true
			consecutive_no_improvement = 0
			
			# SALVA O TEMPO EXATO DA CONVERGÊNCIA
			time_of_best_solution = total_execution_time 
			
			ui_best_cost_label.text = "Melhor Distância: %d (Opção Ótima!)" % int(best_distance_global)
			ui_best_cost_label.modulate = Color(1.0, 0.85, 0.0) 
			
			# ATUALIZA O NOVO LABEL DE TEMPO
			time_of_best_solution = total_execution_time 
			
			ui_best_cost_label.text = "Melhor Distância: %d (Opção Ótima!)" % int(best_distance_global)
			ui_best_cost_label.modulate = Color(1.0, 0.85, 0.0) 
			
			# ATUALIZA A TELA IMEDIATAMENTE AO ACHAR
			ui_time_label.text = "Tempo Total: %.2fs | Melhor em: %.2fs" % [total_execution_time, time_of_best_solution]
			
	if not improved:
		consecutive_no_improvement += 1

func check_stopping_criteria():
	if consecutive_no_improvement >= STAGNATION_LIMIT:
		stop_simulation("CONVERGIU (Estagnação da Solução)")

func stop_simulation(reason: String):
	is_running = false
	ui_status_label.text = "Status: %s" % reason
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
	# A mágica: Ativa o modo completo só se tiver até 15 cidades
	var is_small_map = n <= 15 
	
	for i in range(n):
		for j in range(i + 1, n):
			var pos_i = positions[i]
			var pos_j = positions[j]
			var key = str(i) + "_" + str(j)
			
			var line = Line2D.new()
			# Se for mapa grande, a linha é mais fina e bem mais transparente
			# Se for mapa grande, a linha nasce TOTALMENTE INVISÍVEL (Alpha 0.0)
			line.width = 4.0 if is_small_map else 1.0
			line.default_color = Color(0.0, 0.7, 0.9, 0.15) if is_small_map else Color(0.0, 0.0, 0.0, 0.0)
			line.add_point(pos_i)
			line.add_point(pos_j)
			line_container.add_child(line)
			visual_lines[key] = line
			
			# SÓ GERA AS LABELS (O Gargalo da CPU) SE FOR MAPA PEQUENO!
			if is_small_map:
				var lbl = Label.new()
				var distance = pos_i.distance_to(pos_j)
				lbl.text = str(int(distance))
				
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				lbl.add_theme_font_size_override("font_size", 13)
				lbl.modulate = Color(0.0, 0.0, 0.0, 0.945) 
				
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
				var relative_strength = p_value / max_pheromone
				
				if relative_strength > 0.4:
					line.width = lerp(2.0, 8.0, relative_strength)
					line.modulate.a = lerp(0.3, 1.0, relative_strength)
					
					if relative_strength > 0.85:
						line.default_color = Color(1.0, 0.85, 0.0, 1.0) 
					else:
						line.default_color = Color(0.0, 1.0, 0.4, 1.0) 
					
					# Atualiza o Label APENAS se ele existir no dicionário
					if cost_labels.has(key):
						cost_labels[key].modulate = Color(1.0, 1.0, 1.0, lerp(0.4, 1.0, relative_strength))
						if relative_strength > 0.85:
							cost_labels[key].modulate = Color(1.0, 0.85, 0.0, 1.0)
				else:
					# Resetando caminhos fracos
					if visual_lines.size() <= 105: # 105 linhas = 15 cidades
						line.default_color = Color(0.0, 0.7, 0.9, 0.5)
						line.width = 1.5
					else:
						line.default_color = Color(0.0, 0.0, 0.0, 0.0) # Apaga totalmente em mapas grandes
						
					if cost_labels.has(key):
						cost_labels[key].modulate = Color(1, 1, 1, 0.2)
func animate_ants(tours):
	var ants = ant_container.get_children()
	
	# Se as formigas foram deletadas pelo reset, recria imediatamente
	if ants.size() == 0:
		setup_visual_ants()
		ants = ant_container.get_children()

	for a in range(tours.size()):
		if a >= ants.size(): break
		
		var ant = ants[a]
		var tour = tours[a]
		
		# Força a parada de qualquer movimento anterior antes de aplicar o novo
		if ant_tweens.has(a) and ant_tweens[a] is Tween:
			ant_tweens[a].kill()
			
		var tween = create_tween()
		ant_tweens[a] = tween
		
		# Segurança extra: garante que a rota calculada possui elementos válidos
		if tour.size() > 0 and tour[0] < aco_engine.cities_positions.size():
			ant.position = aco_engine.cities_positions[tour[0]]
		
		# Anima a formiga passando por cada nó
		for i in range(1, tour.size()):
			if tour[i] < aco_engine.cities_positions.size():
				var next_city_pos = aco_engine.cities_positions[tour[i]]
				
				# Ajuste dinâmico do tempo para que elas corram mais rápido quando o delay for curto
				var travel_time = max(0.01, iteration_delay / float(tour.size()))
				
				# Move a formiga
				tween.tween_property(ant, "position", next_city_pos, travel_time)

func _on_btn_reset_pressed() -> void:
	generate_new_simulation()
