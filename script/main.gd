extends Node2D

# Referências aos nós (Seu amigo deve criar estes nós na cena Main)
@onready var aco_engine = $ACOEngine
@onready var city_container = $CityContainer
@onready var line_container = $LineContainer
@onready var ant_container = $AntContainer

# Preloads das cenas visuais (Seu amigo vai criar estas cenas)
var city_scene = preload("res://City.tscn")
var ant_scene = preload("res://Ant.tscn")

# Configurações de execução
var is_running = false
var iteration_delay = 0.5 # Segundos entre iterações
var timer = 0.0

func _ready():
	# 1. Definir posições das cidades (Exemplo: 10 cidades aleatórias)
	var positions = []
	var screen_size = get_viewport_rect().size
	for i in range(10):
		var pos = Vector2(randf_range(100, screen_size.x - 100), randf_range(100, screen_size.y - 100))
		positions.append(pos)
	
	# 2. Instanciar cidades visualmente (Parte do seu amigo)
	setup_visual_cities(positions)
	
	# 3. Configurar as linhas de feromônio (Parte do seu amigo)
	setup_visual_lines(positions)
	
	# 4. Configurar as formigas (Parte do seu amigo)
	setup_visual_ants()

	# 5. Inicializar sua lógica (Rafael)
	aco_engine.setup(positions)
	
	# 6. Conectar seu sinal de lógica ao atualizador visual
	aco_engine.logic_updated.connect(_on_aco_logic_updated)

func _process(delta):
	if is_running:
		timer += delta
		if timer >= iteration_delay:
			aco_engine.run_iteration() # Chama sua lógica!
			timer = 0.0

# --- FUNÇÕES DE INTERFACE (Para conectar aos botões do slide 10) ---

func _on_btn_start_pressed():
	is_running = true

func _on_btn_pause_pressed():
	is_running = false

func _on_speed_slider_value_changed(value):
	# Muda a velocidade: 0.1s (rápido) a 2.0s (lento)
	iteration_delay = value

# --- PONTE ENTRE LÓGICA E VISUAL ---

func _on_aco_logic_updated(pheromones, tours):
	# Esta função recebe os dados que você (Rafael) calculou
	
	# 1. Atualizar a opacidade das linhas de feromônio
	update_pheromone_visuals(pheromones)
	
	# 2. Mover as formigas visualmente pelos caminhos (tours)
	animate_ants(tours)

# --- PLACEHOLDERS PARA O SEU AMIGO (O "VISUAL") ---
# Peça para ele implementar estas funções conforme ele for criando os sprites

func setup_visual_cities(positions):
	for p in positions:
		var city = city_scene.instantiate()
		city.position = p
		city_container.add_child(city)

func setup_visual_lines(positions):
	# Seu amigo vai criar Line2Ds entre todas as cidades aqui
	pass

func setup_visual_ants():
	for i in range(aco_engine.num_ants):
		var ant = ant_scene.instantiate()
		ant_container.add_child(ant)

func update_pheromone_visuals(pheromones):
	# Aqui ele vai percorrer as Line2Ds e mudar a largura/cor baseado na matriz
	pass

func animate_ants(tours):
	# Aqui ele vai usar Tweens para mover as formigas de cidade em cidade
	pass
