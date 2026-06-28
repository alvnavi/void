enum AIProvider { openRouter, cerebras }

class AppSettings {
  String openRouterApiKey;
  String cerebrasApiKey;
  AIProvider activeProvider;
  String targetLanguage;
  String systemInstructions;
  bool useGlobalContext;

  AppSettings({
    this.openRouterApiKey = '',
    this.cerebrasApiKey = '',
    this.activeProvider = AIProvider.openRouter,
    this.targetLanguage = 'Spanish',
    this.systemInstructions = 'SISTEMA: V O I D 🌑 v13.1.0\n\n1. MATRIZ DE DECISIÓN (Prioridad absoluta):\n- ESCENARIO A (NUEVA): Si es un tema nuevo o información no relacionada con la nota abierta.\n- ESCENARIO B (ACTUALIZAR): Solo si hay órdenes de "cambiar", "reagendar" o "agregar" a la nota abierta.\n\n2. REGLAS DE ESTRUCTURA:\n- TITLE: 2-3 palabras (Ej: "# Compra Súper"). Sin fechas.\n- CONTENT: Detalles completos en lista.\n- URGENCIA: Si es prioridad alta, añade al final: **Urgencia**: Alta\n- SUMMARY: Máximo 5 palabras para el índice lateral.\n\n3. CATEGORIZACIÓN DINÁMICA:\n- Clasifica en una CATEGORÍA descriptiva (Ej: "Personas", "Lugares", "Recetas", "Ideas").\n- Si creas o actualizas una categoría (INDEX), añade siempre al final de esa nota un bloque oculto de TAXONOMÍA para mejorar la búsqueda semántica.\n- Ejemplo para CATEGORY: Comida -> Al final de la nota Comida pon: <!-- KEYWORDS: alimentación, nutrición, recetas, hambre, cocina, animales -->.\n\n4. EJEMPLO DE RESPUESTA CORRECTA:\n# Juan Madrid\n- Juan vive en C/ Mayor 15\n\nMETADATA_START\nACTION: NUEVA\nTARGET: NONE\nTITLE: Juan Madrid\nCATEGORY: Personas\nSUMMARY: Contacto de Juan\nMETADATA_END\n\nEXPLICACIÓN DE TAGS:\n- CATEGORY: Crea categorías lógicas. Si la categoría es nueva, la IA debe incluir palabras relacionadas en el bloque KEYWORDS del índice para que el buscador encuentre la relación (ej: Animales -> mascotas, perros).',
    this.useGlobalContext = true,
  });

  Map<String, dynamic> toJson() => {
    'openRouterApiKey': openRouterApiKey,
    'cerebrasApiKey': cerebrasApiKey,
    'activeProvider': activeProvider.index,
    'targetLanguage': targetLanguage,
    'systemInstructions': systemInstructions,
    'useGlobalContext': useGlobalContext,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    openRouterApiKey: json['openRouterApiKey'] ?? '',
    cerebrasApiKey: json['cerebrasApiKey'] ?? '',
    activeProvider: AIProvider.values[(json['activeProvider'] is int) ? json['activeProvider'] : 0],
    targetLanguage: json['targetLanguage'] ?? 'Spanish',
    systemInstructions: json['systemInstructions'] ?? '',
    useGlobalContext: json['useGlobalContext'] ?? true,
  );

  String get activeApiKey => activeProvider == AIProvider.cerebras ? cerebrasApiKey : openRouterApiKey;
}
