-- ============================================================
-- Traducción del currículo de temas (inglés y ruso)
-- Ejecutar en Supabase SQL Editor
--
-- Añade tema_en / tema_ru a curriculo_temas y traduce las 387 filas
-- existentes, para que el desplegable de "tema" al registrar una
-- sesión salga en el idioma que tenga elegido el profesor. Si una
-- fila nueva se añade sin traducir, el desplegable cae al español.
-- ============================================================

ALTER TABLE public.curriculo_temas
  ADD COLUMN IF NOT EXISTS tema_en TEXT,
  ADD COLUMN IF NOT EXISTS tema_ru TEXT;


UPDATE public.curriculo_temas SET tema_en = 'Natural numbers, integers and fractions', tema_ru = 'Натуральные, целые числа и дроби'
WHERE curso = '1º ESO' AND asignatura = 'Matemáticas' AND tema = 'Números naturales, enteros y fracciones';

UPDATE public.curriculo_temas SET tema_en = 'Divisibility', tema_ru = 'Делимость'
WHERE curso = '1º ESO' AND asignatura = 'Matemáticas' AND tema = 'Divisibilidad';

UPDATE public.curriculo_temas SET tema_en = 'Powers and roots', tema_ru = 'Степени и корни'
WHERE curso = '1º ESO' AND asignatura = 'Matemáticas' AND tema = 'Potencias y raíces';

UPDATE public.curriculo_temas SET tema_en = 'Proportionality and percentages', tema_ru = 'Пропорциональность и проценты'
WHERE curso = '1º ESO' AND asignatura = 'Matemáticas' AND tema = 'Proporcionalidad y porcentajes';

UPDATE public.curriculo_temas SET tema_en = 'Introduction to algebra: expressions and simple equations', tema_ru = 'Введение в алгебру: выражения и простые уравнения'
WHERE curso = '1º ESO' AND asignatura = 'Matemáticas' AND tema = 'Iniciación al álgebra: expresiones y ecuaciones sencillas';

UPDATE public.curriculo_temas SET tema_en = 'Plane figures: perimeters and areas', tema_ru = 'Плоские фигуры: периметры и площади'
WHERE curso = '1º ESO' AND asignatura = 'Matemáticas' AND tema = 'Figuras planas: perímetros y áreas';

UPDATE public.curriculo_temas SET tema_en = 'Coordinate system', tema_ru = 'Система координат'
WHERE curso = '1º ESO' AND asignatura = 'Matemáticas' AND tema = 'Sistema de coordenadas';

UPDATE public.curriculo_temas SET tema_en = 'Statistical tables and graphs', tema_ru = 'Статистические таблицы и графики'
WHERE curso = '1º ESO' AND asignatura = 'Matemáticas' AND tema = 'Tablas y gráficos estadísticos';

UPDATE public.curriculo_temas SET tema_en = 'Chance and probability', tema_ru = 'Случайность и вероятность'
WHERE curso = '1º ESO' AND asignatura = 'Matemáticas' AND tema = 'Azar y probabilidad';

UPDATE public.curriculo_temas SET tema_en = 'Emotional management and teamwork', tema_ru = 'Управление эмоциями и работа в команде'
WHERE curso = '1º ESO' AND asignatura = 'Matemáticas' AND tema = 'Gestión emocional y trabajo en equipo';

UPDATE public.curriculo_temas SET tema_en = 'The multilingual reality of Spain', tema_ru = 'Многоязычная реальность Испании'
WHERE curso = '1º ESO' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'Realidad plurilingüe de España';

UPDATE public.curriculo_temas SET tema_en = 'Oral communication: listening and speaking', tema_ru = 'Устное общение: слушание и говорение'
WHERE curso = '1º ESO' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'Comunicación oral: escuchar y hablar';

UPDATE public.curriculo_temas SET tema_en = 'Reading comprehension and written production', tema_ru = 'Понимание текста и письменная речь'
WHERE curso = '1º ESO' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'Comprensión lectora y producción escrita';

UPDATE public.curriculo_temas SET tema_en = 'Narrative and descriptive texts', tema_ru = 'Повествовательный и описательный текст'
WHERE curso = '1º ESO' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'El texto narrativo y descriptivo';

UPDATE public.curriculo_temas SET tema_en = 'Literary genres', tema_ru = 'Литературные жанры'
WHERE curso = '1º ESO' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'Géneros literarios';

UPDATE public.curriculo_temas SET tema_en = 'Reading of literary works', tema_ru = 'Чтение художественных произведений'
WHERE curso = '1º ESO' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'Lectura de obras literarias';

UPDATE public.curriculo_temas SET tema_en = 'Grammar: word classes and the simple sentence', tema_ru = 'Грамматика: части речи и простое предложение'
WHERE curso = '1º ESO' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'Gramática: categorías y oración simple';

UPDATE public.curriculo_temas SET tema_en = 'Vocabulary and spelling', tema_ru = 'Лексика и правописание'
WHERE curso = '1º ESO' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'Léxico y ortografía';

UPDATE public.curriculo_temas SET tema_en = 'Linguistic diversity and oral communication', tema_ru = 'Языковое разнообразие и устное общение'
WHERE curso = '1º ESO' AND asignatura = 'Valenciano' AND tema = 'Diversitat lingüística i comunicació oral';

UPDATE public.curriculo_temas SET tema_en = 'Reading comprehension and written production', tema_ru = 'Понимание текста и письменная речь'
WHERE curso = '1º ESO' AND asignatura = 'Valenciano' AND tema = 'Comprensió lectora i producció escrita';

UPDATE public.curriculo_temas SET tema_en = 'Narrative and descriptive texts', tema_ru = 'Повествовательный и описательный текст'
WHERE curso = '1º ESO' AND asignatura = 'Valenciano' AND tema = 'El text narratiu i descriptiu';

UPDATE public.curriculo_temas SET tema_en = 'Literary genres', tema_ru = 'Литературные жанры'
WHERE curso = '1º ESO' AND asignatura = 'Valenciano' AND tema = 'Gèneres literaris';

UPDATE public.curriculo_temas SET tema_en = 'Reading works in Valencian', tema_ru = 'Чтение произведений на валенсийском языке'
WHERE curso = '1º ESO' AND asignatura = 'Valenciano' AND tema = 'Lectura d''obres en valencià';

UPDATE public.curriculo_temas SET tema_en = 'Grammar: word classes and the simple sentence', tema_ru = 'Грамматика: части речи и простое предложение'
WHERE curso = '1º ESO' AND asignatura = 'Valenciano' AND tema = 'Gramàtica: categories i oració simple';

UPDATE public.curriculo_temas SET tema_en = 'Valencian vocabulary and spelling', tema_ru = 'Лексика и правописание валенсийского языка'
WHERE curso = '1º ESO' AND asignatura = 'Valenciano' AND tema = 'Lèxic i ortografia valenciana';

UPDATE public.curriculo_temas SET tema_en = 'Listening and reading comprehension', tema_ru = 'Понимание устной и письменной речи'
WHERE curso = '1º ESO' AND asignatura = 'Inglés' AND tema = 'Comprensión oral y escrita';

UPDATE public.curriculo_temas SET tema_en = 'Oral and written production and interaction', tema_ru = 'Устная и письменная продукция и взаимодействие'
WHERE curso = '1º ESO' AND asignatura = 'Inglés' AND tema = 'Producción e interacción oral y escrita';

UPDATE public.curriculo_temas SET tema_en = 'Everyday communicative functions', tema_ru = 'Повседневные коммуникативные функции'
WHERE curso = '1º ESO' AND asignatura = 'Inglés' AND tema = 'Funciones comunicativas cotidianas';

UPDATE public.curriculo_temas SET tema_en = 'Grammar and vocabulary for this level', tema_ru = 'Грамматика и словарный запас уровня'
WHERE curso = '1º ESO' AND asignatura = 'Inglés' AND tema = 'Gramática y léxico de nivel';

UPDATE public.curriculo_temas SET tema_en = 'Mediation and comprehension strategies', tema_ru = 'Стратегии медиации и понимания'
WHERE curso = '1º ESO' AND asignatura = 'Inglés' AND tema = 'Estrategias de mediación y comprensión';

UPDATE public.curriculo_temas SET tema_en = 'Cultural aspects and multilingualism', tema_ru = 'Культурные аспекты и многоязычие'
WHERE curso = '1º ESO' AND asignatura = 'Inglés' AND tema = 'Aspectos culturales y plurilingüismo';

UPDATE public.curriculo_temas SET tema_en = 'The scientific method and lab work', tema_ru = 'Научный метод и лабораторная работа'
WHERE curso = '1º ESO' AND asignatura = 'Biología y Geología' AND tema = 'Método científico y trabajo de laboratorio';

UPDATE public.curriculo_temas SET tema_en = 'Earth in the universe and the Solar System', tema_ru = 'Земля во Вселенной и Солнечная система'
WHERE curso = '1º ESO' AND asignatura = 'Biología y Geología' AND tema = 'La Tierra en el universo y el Sistema Solar';

UPDATE public.curriculo_temas SET tema_en = 'The geosphere: minerals and rocks', tema_ru = 'Геосфера: минералы и горные породы'
WHERE curso = '1º ESO' AND asignatura = 'Biología y Geología' AND tema = 'La geosfera: minerales y rocas';

UPDATE public.curriculo_temas SET tema_en = 'The atmosphere', tema_ru = 'Атмосфера'
WHERE curso = '1º ESO' AND asignatura = 'Biología y Geología' AND tema = 'La atmósfera';

UPDATE public.curriculo_temas SET tema_en = 'The hydrosphere', tema_ru = 'Гидросфера'
WHERE curso = '1º ESO' AND asignatura = 'Biología y Geología' AND tema = 'La hidrosfera';

UPDATE public.curriculo_temas SET tema_en = 'The cell', tema_ru = 'Клетка'
WHERE curso = '1º ESO' AND asignatura = 'Biología y Geología' AND tema = 'La célula';

UPDATE public.curriculo_temas SET tema_en = 'Classification of living things: the five kingdoms', tema_ru = 'Классификация живых организмов: пять царств'
WHERE curso = '1º ESO' AND asignatura = 'Biología y Geología' AND tema = 'Clasificación de los seres vivos: los cinco reinos';

UPDATE public.curriculo_temas SET tema_en = 'Invertebrates and vertebrates', tema_ru = 'Беспозвоночные и позвоночные'
WHERE curso = '1º ESO' AND asignatura = 'Biología y Geología' AND tema = 'Invertebrados y vertebrados';

UPDATE public.curriculo_temas SET tema_en = 'Plants', tema_ru = 'Растения'
WHERE curso = '1º ESO' AND asignatura = 'Biología y Geología' AND tema = 'Las plantas';

UPDATE public.curriculo_temas SET tema_en = 'Ecosystems', tema_ru = 'Экосистемы'
WHERE curso = '1º ESO' AND asignatura = 'Biología y Geología' AND tema = 'Ecosistemas';

UPDATE public.curriculo_temas SET tema_en = 'Planet Earth: relief, climate and landscapes', tema_ru = 'Планета Земля: рельеф, климат и ландшафты'
WHERE curso = '1º ESO' AND asignatura = 'Geografía e Historia' AND tema = 'El planeta Tierra: relieve, clima y paisajes';

UPDATE public.curriculo_temas SET tema_en = 'The physical geography of Europe and Spain', tema_ru = 'Физическая география Европы и Испании'
WHERE curso = '1º ESO' AND asignatura = 'Geografía e Historia' AND tema = 'Medio físico de Europa y España';

UPDATE public.curriculo_temas SET tema_en = 'Prehistory', tema_ru = 'Доисторическая эпоха'
WHERE curso = '1º ESO' AND asignatura = 'Geografía e Historia' AND tema = 'La Prehistoria';

UPDATE public.curriculo_temas SET tema_en = 'The first civilisations: Mesopotamia and Egypt', tema_ru = 'Первые цивилизации: Месопотамия и Египет'
WHERE curso = '1º ESO' AND asignatura = 'Geografía e Historia' AND tema = 'Las primeras civilizaciones: Mesopotamia y Egipto';

UPDATE public.curriculo_temas SET tema_en = 'Greece', tema_ru = 'Греция'
WHERE curso = '1º ESO' AND asignatura = 'Geografía e Historia' AND tema = 'Grecia';

UPDATE public.curriculo_temas SET tema_en = 'Rome', tema_ru = 'Рим'
WHERE curso = '1º ESO' AND asignatura = 'Geografía e Historia' AND tema = 'Roma';

UPDATE public.curriculo_temas SET tema_en = 'Introduction to comprehension and production', tema_ru = 'Введение в понимание и продукцию речи'
WHERE curso = '1º ESO' AND asignatura = 'Francés' AND tema = 'Iniciación a la comprensión y producción';

UPDATE public.curriculo_temas SET tema_en = 'Basic communicative functions', tema_ru = 'Базовые коммуникативные функции'
WHERE curso = '1º ESO' AND asignatura = 'Francés' AND tema = 'Funciones comunicativas básicas';

UPDATE public.curriculo_temas SET tema_en = 'Basic vocabulary', tema_ru = 'Элементарная лексика'
WHERE curso = '1º ESO' AND asignatura = 'Francés' AND tema = 'Léxico elemental';

UPDATE public.curriculo_temas SET tema_en = 'French-speaking culture', tema_ru = 'Культура франкоязычных стран'
WHERE curso = '1º ESO' AND asignatura = 'Francés' AND tema = 'Cultura francófona';

UPDATE public.curriculo_temas SET tema_en = 'Integers, fractions and decimals', tema_ru = 'Целые числа, дроби и десятичные дроби'
WHERE curso = '2º ESO' AND asignatura = 'Matemáticas' AND tema = 'Números enteros, fracciones y decimales';

UPDATE public.curriculo_temas SET tema_en = 'Proportionality', tema_ru = 'Пропорциональность'
WHERE curso = '2º ESO' AND asignatura = 'Matemáticas' AND tema = 'Proporcionalidad';

UPDATE public.curriculo_temas SET tema_en = 'Powers and square roots', tema_ru = 'Степени и квадратные корни'
WHERE curso = '2º ESO' AND asignatura = 'Matemáticas' AND tema = 'Potencias y raíces cuadradas';

UPDATE public.curriculo_temas SET tema_en = 'Algebra: first-degree equations', tema_ru = 'Алгебра: уравнения первой степени'
WHERE curso = '2º ESO' AND asignatura = 'Matemáticas' AND tema = 'Álgebra: ecuaciones de primer grado';

UPDATE public.curriculo_temas SET tema_en = 'Pythagoras'' theorem', tema_ru = 'Теорема Пифагора'
WHERE curso = '2º ESO' AND asignatura = 'Matemáticas' AND tema = 'Teorema de Pitágoras';

UPDATE public.curriculo_temas SET tema_en = 'Geometric figures and solids: areas and volumes', tema_ru = 'Геометрические фигуры и тела: площади и объёмы'
WHERE curso = '2º ESO' AND asignatura = 'Matemáticas' AND tema = 'Figuras y cuerpos geométricos: áreas y volúmenes';

UPDATE public.curriculo_temas SET tema_en = 'Functions and graphs: introduction', tema_ru = 'Функции и графики: введение'
WHERE curso = '2º ESO' AND asignatura = 'Matemáticas' AND tema = 'Funciones y gráficas: iniciación';

UPDATE public.curriculo_temas SET tema_en = 'Statistics and probability', tema_ru = 'Статистика и вероятность'
WHERE curso = '2º ESO' AND asignatura = 'Matemáticas' AND tema = 'Estadística y probabilidad';

UPDATE public.curriculo_temas SET tema_en = 'Oral and written communication', tema_ru = 'Устное и письменное общение'
WHERE curso = '2º ESO' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'Comunicación oral y escrita';

UPDATE public.curriculo_temas SET tema_en = 'Text types', tema_ru = 'Типы текстов'
WHERE curso = '2º ESO' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'Tipologías textuales';

UPDATE public.curriculo_temas SET tema_en = 'Instructional and expository texts', tema_ru = 'Инструктивный и информативный текст'
WHERE curso = '2º ESO' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'El texto instructivo y expositivo';

UPDATE public.curriculo_temas SET tema_en = 'Literary genres: narrative, poetry, drama', tema_ru = 'Литературные жанры: повествование, лирика, драма'
WHERE curso = '2º ESO' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'Géneros literarios: narrativa, lírica, teatro';

UPDATE public.curriculo_temas SET tema_en = 'Grammar: syntax of the simple sentence', tema_ru = 'Грамматика: синтаксис простого предложения'
WHERE curso = '2º ESO' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'Gramática: sintaxis de la oración simple';

UPDATE public.curriculo_temas SET tema_en = 'Vocabulary and spelling', tema_ru = 'Лексика и правописание'
WHERE curso = '2º ESO' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'Léxico y ortografía';

UPDATE public.curriculo_temas SET tema_en = 'Oral and written communication', tema_ru = 'Устное и письменное общение'
WHERE curso = '2º ESO' AND asignatura = 'Valenciano' AND tema = 'Comunicació oral i escrita';

UPDATE public.curriculo_temas SET tema_en = 'Text types', tema_ru = 'Типы текстов'
WHERE curso = '2º ESO' AND asignatura = 'Valenciano' AND tema = 'Tipologies textuals';

UPDATE public.curriculo_temas SET tema_en = 'Instructional and expository texts', tema_ru = 'Инструктивный и информативный текст'
WHERE curso = '2º ESO' AND asignatura = 'Valenciano' AND tema = 'El text instructiu i expositiu';

UPDATE public.curriculo_temas SET tema_en = 'Literary genres: narrative, poetry, drama', tema_ru = 'Литературные жанры: повествование, лирика, драма'
WHERE curso = '2º ESO' AND asignatura = 'Valenciano' AND tema = 'Gèneres literaris: narrativa, lírica, teatre';

UPDATE public.curriculo_temas SET tema_en = 'Grammar: syntax of the simple sentence', tema_ru = 'Грамматика: синтаксис простого предложения'
WHERE curso = '2º ESO' AND asignatura = 'Valenciano' AND tema = 'Gramàtica: sintaxi de l''oració simple';

UPDATE public.curriculo_temas SET tema_en = 'Valencian vocabulary and spelling', tema_ru = 'Лексика и правописание валенсийского языка'
WHERE curso = '2º ESO' AND asignatura = 'Valenciano' AND tema = 'Lèxic i ortografia valenciana';

UPDATE public.curriculo_temas SET tema_en = 'Oral and written comprehension and production', tema_ru = 'Понимание и продукция устной и письменной речи'
WHERE curso = '2º ESO' AND asignatura = 'Inglés' AND tema = 'Comprensión y producción oral y escrita';

UPDATE public.curriculo_temas SET tema_en = 'Intermediate-level communicative functions', tema_ru = 'Коммуникативные функции среднего уровня'
WHERE curso = '2º ESO' AND asignatura = 'Inglés' AND tema = 'Funciones comunicativas de nivel intermedio';

UPDATE public.curriculo_temas SET tema_en = 'Grammar and vocabulary for this level', tema_ru = 'Грамматика и словарный запас уровня'
WHERE curso = '2º ESO' AND asignatura = 'Inglés' AND tema = 'Gramática y léxico de nivel';

UPDATE public.curriculo_temas SET tema_en = 'Mediation strategies', tema_ru = 'Стратегии медиации'
WHERE curso = '2º ESO' AND asignatura = 'Inglés' AND tema = 'Estrategias de mediación';

UPDATE public.curriculo_temas SET tema_en = 'Cultural aspects', tema_ru = 'Культурные аспекты'
WHERE curso = '2º ESO' AND asignatura = 'Inglés' AND tema = 'Aspectos culturales';

UPDATE public.curriculo_temas SET tema_en = 'The scientific method, quantities and the International System of Units', tema_ru = 'Научный метод, величины и Международная система единиц'
WHERE curso = '2º ESO' AND asignatura = 'Física y Química' AND tema = 'Método científico, magnitudes y Sistema Internacional';

UPDATE public.curriculo_temas SET tema_en = 'Properties of matter and states of matter', tema_ru = 'Свойства вещества и агрегатные состояния'
WHERE curso = '2º ESO' AND asignatura = 'Física y Química' AND tema = 'Propiedades de la materia y estados de agregación';

UPDATE public.curriculo_temas SET tema_en = 'The kinetic-molecular model', tema_ru = 'Кинетико-молекулярная модель'
WHERE curso = '2º ESO' AND asignatura = 'Física y Química' AND tema = 'Modelo cinético-molecular';

UPDATE public.curriculo_temas SET tema_en = 'Pure substances and mixtures: separation', tema_ru = 'Чистые вещества и смеси: разделение'
WHERE curso = '2º ESO' AND asignatura = 'Física y Química' AND tema = 'Sustancias puras y mezclas: separación';

UPDATE public.curriculo_temas SET tema_en = 'Energy and its forms', tema_ru = 'Энергия и её формы'
WHERE curso = '2º ESO' AND asignatura = 'Física y Química' AND tema = 'La energía y sus formas';

UPDATE public.curriculo_temas SET tema_en = 'Physical and chemical change: introduction to the chemical reaction', tema_ru = 'Физические и химические изменения: введение в химическую реакцию'
WHERE curso = '2º ESO' AND asignatura = 'Física y Química' AND tema = 'El cambio físico y químico: introducción a la reacción química';

UPDATE public.curriculo_temas SET tema_en = 'Feudal Europe', tema_ru = 'Феодальная Европа'
WHERE curso = '2º ESO' AND asignatura = 'Geografía e Historia' AND tema = 'La Europa feudal';

UPDATE public.curriculo_temas SET tema_en = 'Islam and Al-Andalus', tema_ru = 'Ислам и Аль-Андалус'
WHERE curso = '2º ESO' AND asignatura = 'Geografía e Historia' AND tema = 'El islam y Al-Ándalus';

UPDATE public.curriculo_temas SET tema_en = 'The Christian kingdoms of the Iberian Peninsula', tema_ru = 'Христианские королевства Пиренейского полуострова'
WHERE curso = '2º ESO' AND asignatura = 'Geografía e Historia' AND tema = 'Los reinos cristianos peninsulares';

UPDATE public.curriculo_temas SET tema_en = 'The medieval city', tema_ru = 'Средневековый город'
WHERE curso = '2º ESO' AND asignatura = 'Geografía e Historia' AND tema = 'La ciudad medieval';

UPDATE public.curriculo_temas SET tema_en = 'The Renaissance and Humanism', tema_ru = 'Ренессанс и гуманизм'
WHERE curso = '2º ESO' AND asignatura = 'Geografía e Historia' AND tema = 'El Renacimiento y el Humanismo';

UPDATE public.curriculo_temas SET tema_en = 'The Early Modern Age: 15th-18th centuries', tema_ru = 'Новая история: XV-XVIII века'
WHERE curso = '2º ESO' AND asignatura = 'Geografía e Historia' AND tema = 'La Edad Moderna: siglos XV-XVIII';

UPDATE public.curriculo_temas SET tema_en = 'The geographical discoveries', tema_ru = 'Географические открытия'
WHERE curso = '2º ESO' AND asignatura = 'Geografía e Historia' AND tema = 'Los descubrimientos geográficos';

UPDATE public.curriculo_temas SET tema_en = 'Rational and real numbers', tema_ru = 'Рациональные и действительные числа'
WHERE curso = '3º ESO' AND asignatura = 'Matemáticas' AND tema = 'Números racionales y reales';

UPDATE public.curriculo_temas SET tema_en = 'Powers and scientific notation', tema_ru = 'Степени и научная запись чисел'
WHERE curso = '3º ESO' AND asignatura = 'Matemáticas' AND tema = 'Potencias y notación científica';

UPDATE public.curriculo_temas SET tema_en = 'Polynomials and equations/systems', tema_ru = 'Многочлены и уравнения/системы'
WHERE curso = '3º ESO' AND asignatura = 'Matemáticas' AND tema = 'Polinomios y ecuaciones/sistemas';

UPDATE public.curriculo_temas SET tema_en = 'Sequences', tema_ru = 'Последовательности'
WHERE curso = '3º ESO' AND asignatura = 'Matemáticas' AND tema = 'Sucesiones';

UPDATE public.curriculo_temas SET tema_en = 'Geometry: similarity and geometric solids', tema_ru = 'Геометрия: подобие и геометрические тела'
WHERE curso = '3º ESO' AND asignatura = 'Matemáticas' AND tema = 'Geometría: semejanza y cuerpos geométricos';

UPDATE public.curriculo_temas SET tema_en = 'Linear and quadratic functions', tema_ru = 'Линейные и квадратичные функции'
WHERE curso = '3º ESO' AND asignatura = 'Matemáticas' AND tema = 'Funciones lineales y cuadráticas';

UPDATE public.curriculo_temas SET tema_en = 'Statistics and probability', tema_ru = 'Статистика и вероятность'
WHERE curso = '3º ESO' AND asignatura = 'Matemáticas' AND tema = 'Estadística y probabilidad';

UPDATE public.curriculo_temas SET tema_en = 'Varieties of Spanish and the languages of Spain', tema_ru = 'Варианты испанского языка и языки Испании'
WHERE curso = '3º ESO' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'Variedades del español y lenguas de España';

UPDATE public.curriculo_temas SET tema_en = 'Formal oral communication', tema_ru = 'Формальное устное общение'
WHERE curso = '3º ESO' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'Comunicación oral formal';

UPDATE public.curriculo_temas SET tema_en = 'Expository-argumentative text', tema_ru = 'Информативно-аргументативный текст'
WHERE curso = '3º ESO' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'Texto expositivo-argumentativo';

UPDATE public.curriculo_temas SET tema_en = 'Medieval literature and the Golden Age', tema_ru = 'Средневековая литература и литература Золотого века'
WHERE curso = '3º ESO' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'Literatura medieval y de los Siglos de Oro';

UPDATE public.curriculo_temas SET tema_en = 'Sentence syntax', tema_ru = 'Синтаксис предложения'
WHERE curso = '3º ESO' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'Sintaxis de la oración';

UPDATE public.curriculo_temas SET tema_en = 'Vocabulary and spelling', tema_ru = 'Лексика и правописание'
WHERE curso = '3º ESO' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'Léxico y ortografía';

UPDATE public.curriculo_temas SET tema_en = 'Varieties of Valencian and sociolinguistics', tema_ru = 'Варианты валенсийского языка и социолингвистика'
WHERE curso = '3º ESO' AND asignatura = 'Valenciano' AND tema = 'Varietats del valencià i sociolingüística';

UPDATE public.curriculo_temas SET tema_en = 'Formal oral communication', tema_ru = 'Формальное устное общение'
WHERE curso = '3º ESO' AND asignatura = 'Valenciano' AND tema = 'Comunicació oral formal';

UPDATE public.curriculo_temas SET tema_en = 'Expository-argumentative text', tema_ru = 'Информативно-аргументативный текст'
WHERE curso = '3º ESO' AND asignatura = 'Valenciano' AND tema = 'Text expositiu-argumentatiu';

UPDATE public.curriculo_temas SET tema_en = 'Medieval literature and the Golden Age in Valencian', tema_ru = 'Средневековая литература и литература Золотого века на валенсийском'
WHERE curso = '3º ESO' AND asignatura = 'Valenciano' AND tema = 'Literatura medieval i dels Segles d''Or en valencià';

UPDATE public.curriculo_temas SET tema_en = 'Sentence syntax', tema_ru = 'Синтаксис предложения'
WHERE curso = '3º ESO' AND asignatura = 'Valenciano' AND tema = 'Sintaxi de l''oració';

UPDATE public.curriculo_temas SET tema_en = 'Valencian vocabulary and spelling', tema_ru = 'Лексика и правописание валенсийского языка'
WHERE curso = '3º ESO' AND asignatura = 'Valenciano' AND tema = 'Lèxic i ortografia valenciana';

UPDATE public.curriculo_temas SET tema_en = 'Oral and written comprehension and production (B1)', tema_ru = 'Понимание и продукция устной и письменной речи (B1)'
WHERE curso = '3º ESO' AND asignatura = 'Inglés' AND tema = 'Comprensión y producción oral y escrita (B1)';

UPDATE public.curriculo_temas SET tema_en = 'Intermediate-level communicative functions', tema_ru = 'Коммуникативные функции среднего уровня'
WHERE curso = '3º ESO' AND asignatura = 'Inglés' AND tema = 'Funciones comunicativas de nivel intermedio';

UPDATE public.curriculo_temas SET tema_en = 'Grammar and vocabulary at B1 level', tema_ru = 'Грамматика и словарный запас уровня B1'
WHERE curso = '3º ESO' AND asignatura = 'Inglés' AND tema = 'Gramática y léxico de nivel B1';

UPDATE public.curriculo_temas SET tema_en = 'Mediation strategies', tema_ru = 'Стратегии медиации'
WHERE curso = '3º ESO' AND asignatura = 'Inglés' AND tema = 'Estrategias de mediación';

UPDATE public.curriculo_temas SET tema_en = 'Sociocultural aspects', tema_ru = 'Социокультурные аспекты'
WHERE curso = '3º ESO' AND asignatura = 'Inglés' AND tema = 'Aspectos socioculturales';

UPDATE public.curriculo_temas SET tema_en = 'The cell and tissues', tema_ru = 'Клетка и ткани'
WHERE curso = '3º ESO' AND asignatura = 'Biología y Geología' AND tema = 'La célula y los tejidos';

UPDATE public.curriculo_temas SET tema_en = 'Health and disease', tema_ru = 'Здоровье и болезнь'
WHERE curso = '3º ESO' AND asignatura = 'Biología y Geología' AND tema = 'La salud y la enfermedad';

UPDATE public.curriculo_temas SET tema_en = 'Nutrition: the digestive, respiratory, circulatory and excretory systems', tema_ru = 'Питание: пищеварительная, дыхательная, кровеносная и выделительная системы'
WHERE curso = '3º ESO' AND asignatura = 'Biología y Geología' AND tema = 'Nutrición: aparatos digestivo, respiratorio, circulatorio y excretor';

UPDATE public.curriculo_temas SET tema_en = 'Relation: nervous and endocrine systems and sense organs', tema_ru = 'Взаимодействие со средой: нервная, эндокринная системы и органы чувств'
WHERE curso = '3º ESO' AND asignatura = 'Biología y Geología' AND tema = 'Relación: sistema nervioso, endocrino y órganos de los sentidos';

UPDATE public.curriculo_temas SET tema_en = 'Human reproduction', tema_ru = 'Размножение человека'
WHERE curso = '3º ESO' AND asignatura = 'Biología y Geología' AND tema = 'Reproducción humana';

UPDATE public.curriculo_temas SET tema_en = 'External and internal geology: relief and its shaping', tema_ru = 'Внешняя и внутренняя геология: рельеф и его формирование'
WHERE curso = '3º ESO' AND asignatura = 'Biología y Geología' AND tema = 'Geología externa e interna: relieve y su modelado';

UPDATE public.curriculo_temas SET tema_en = 'The scientific method', tema_ru = 'Научный метод'
WHERE curso = '3º ESO' AND asignatura = 'Física y Química' AND tema = 'Método científico';

UPDATE public.curriculo_temas SET tema_en = 'Atomic structure, isotopes and atomic models', tema_ru = 'Строение атома, изотопы и атомные модели'
WHERE curso = '3º ESO' AND asignatura = 'Física y Química' AND tema = 'Estructura atómica, isótopos y modelos atómicos';

UPDATE public.curriculo_temas SET tema_en = 'The Periodic Table', tema_ru = 'Периодическая таблица'
WHERE curso = '3º ESO' AND asignatura = 'Física y Química' AND tema = 'El Sistema Periódico';

UPDATE public.curriculo_temas SET tema_en = 'Bonds between atoms', tema_ru = 'Связи между атомами'
WHERE curso = '3º ESO' AND asignatura = 'Física y Química' AND tema = 'Uniones entre átomos';

UPDATE public.curriculo_temas SET tema_en = 'Formulation and nomenclature of binary compounds (IUPAC)', tema_ru = 'Составление формул и номенклатура бинарных соединений (ИЮПАК)'
WHERE curso = '3º ESO' AND asignatura = 'Física y Química' AND tema = 'Formulación y nomenclatura de compuestos binarios (IUPAC)';

UPDATE public.curriculo_temas SET tema_en = 'The chemical reaction and stoichiometric calculations', tema_ru = 'Химическая реакция и стехиометрические расчёты'
WHERE curso = '3º ESO' AND asignatura = 'Física y Química' AND tema = 'La reacción química y cálculos estequiométricos';

UPDATE public.curriculo_temas SET tema_en = 'The law of conservation of mass', tema_ru = 'Закон сохранения массы'
WHERE curso = '3º ESO' AND asignatura = 'Física y Química' AND tema = 'Ley de conservación de la masa';

UPDATE public.curriculo_temas SET tema_en = 'Chemistry, society and the environment', tema_ru = 'Химия, общество и окружающая среда'
WHERE curso = '3º ESO' AND asignatura = 'Física y Química' AND tema = 'Química, sociedad y medio ambiente';

UPDATE public.curriculo_temas SET tema_en = 'Population and migratory movements', tema_ru = 'Население и миграционные процессы'
WHERE curso = '3º ESO' AND asignatura = 'Geografía e Historia' AND tema = 'Población y movimientos migratorios';

UPDATE public.curriculo_temas SET tema_en = 'Urban and rural space', tema_ru = 'Городское и сельское пространство'
WHERE curso = '3º ESO' AND asignatura = 'Geografía e Historia' AND tema = 'El espacio urbano y rural';

UPDATE public.curriculo_temas SET tema_en = 'The economic sectors', tema_ru = 'Секторы экономики'
WHERE curso = '3º ESO' AND asignatura = 'Geografía e Historia' AND tema = 'Los sectores económicos';

UPDATE public.curriculo_temas SET tema_en = 'Globalisation and political organisation', tema_ru = 'Глобализация и политическая организация'
WHERE curso = '3º ESO' AND asignatura = 'Geografía e Historia' AND tema = 'Globalización y organización política';

UPDATE public.curriculo_temas SET tema_en = 'Spain and the Valencian Community', tema_ru = 'Испания и Валенсийское сообщество'
WHERE curso = '3º ESO' AND asignatura = 'Geografía e Historia' AND tema = 'España y la Comunitat Valenciana';

UPDATE public.curriculo_temas SET tema_en = 'The SDGs and sustainable development', tema_ru = 'ЦУР и устойчивое развитие'
WHERE curso = '3º ESO' AND asignatura = 'Geografía e Historia' AND tema = 'Los ODS y el desarrollo sostenible';

UPDATE public.curriculo_temas SET tema_en = 'Real numbers and percentages', tema_ru = 'Действительные числа и проценты'
WHERE curso = '4º ESO' AND asignatura = 'Matemáticas A' AND tema = 'Números reales y porcentajes';

UPDATE public.curriculo_temas SET tema_en = 'Basic financial mathematics', tema_ru = 'Основы финансовой математики'
WHERE curso = '4º ESO' AND asignatura = 'Matemáticas A' AND tema = 'Matemática financiera básica';

UPDATE public.curriculo_temas SET tema_en = 'Applied algebra', tema_ru = 'Прикладная алгебра'
WHERE curso = '4º ESO' AND asignatura = 'Matemáticas A' AND tema = 'Álgebra aplicada';

UPDATE public.curriculo_temas SET tema_en = 'Functions and graphs', tema_ru = 'Функции и графики'
WHERE curso = '4º ESO' AND asignatura = 'Matemáticas A' AND tema = 'Funciones y gráficas';

UPDATE public.curriculo_temas SET tema_en = 'Applied statistics and probability', tema_ru = 'Прикладная статистика и вероятность'
WHERE curso = '4º ESO' AND asignatura = 'Matemáticas A' AND tema = 'Estadística y probabilidad aplicadas';

UPDATE public.curriculo_temas SET tema_en = 'Real numbers and radicals', tema_ru = 'Действительные числа и корни'
WHERE curso = '4º ESO' AND asignatura = 'Matemáticas B' AND tema = 'Números reales y radicales';

UPDATE public.curriculo_temas SET tema_en = 'Polynomials and algebraic fractions', tema_ru = 'Многочлены и алгебраические дроби'
WHERE curso = '4º ESO' AND asignatura = 'Matemáticas B' AND tema = 'Polinomios y fracciones algebraicas';

UPDATE public.curriculo_temas SET tema_en = 'Equations, inequalities and systems', tema_ru = 'Уравнения, неравенства и системы'
WHERE curso = '4º ESO' AND asignatura = 'Matemáticas B' AND tema = 'Ecuaciones, inecuaciones y sistemas';

UPDATE public.curriculo_temas SET tema_en = 'Trigonometry', tema_ru = 'Тригонометрия'
WHERE curso = '4º ESO' AND asignatura = 'Matemáticas B' AND tema = 'Trigonometría';

UPDATE public.curriculo_temas SET tema_en = 'Analytic geometry', tema_ru = 'Аналитическая геометрия'
WHERE curso = '4º ESO' AND asignatura = 'Matemáticas B' AND tema = 'Geometría analítica';

UPDATE public.curriculo_temas SET tema_en = 'Functions: polynomial, exponential, logarithmic', tema_ru = 'Функции: многочленные, показательные, логарифмические'
WHERE curso = '4º ESO' AND asignatura = 'Matemáticas B' AND tema = 'Funciones: polinómicas, exponenciales, logarítmicas';

UPDATE public.curriculo_temas SET tema_en = 'Statistics and probability', tema_ru = 'Статистика и вероятность'
WHERE curso = '4º ESO' AND asignatura = 'Matemáticas B' AND tema = 'Estadística y probabilidad';

UPDATE public.curriculo_temas SET tema_en = 'Communication and advanced text types', tema_ru = 'Общение и продвинутые типы текстов'
WHERE curso = '4º ESO' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'Comunicación y tipologías textuales avanzadas';

UPDATE public.curriculo_temas SET tema_en = '18th- and 19th-century literature: Romanticism and Realism', tema_ru = 'Литература XVIII-XIX веков: романтизм и реализм'
WHERE curso = '4º ESO' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'Literatura del siglo XVIII y XIX: Romanticismo y Realismo';

UPDATE public.curriculo_temas SET tema_en = '20th-century literature: the Generation of 98, of 27, and contemporary literature', tema_ru = 'Литература XX века: поколение 98-го, поколение 27-го и современная литература'
WHERE curso = '4º ESO' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'Literatura del siglo XX: Generación del 98, del 27 y contemporánea';

UPDATE public.curriculo_temas SET tema_en = 'Syntax of the compound sentence', tema_ru = 'Синтаксис сложного предложения'
WHERE curso = '4º ESO' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'Sintaxis de la oración compuesta';

UPDATE public.curriculo_temas SET tema_en = 'Vocabulary and spelling', tema_ru = 'Лексика и правописание'
WHERE curso = '4º ESO' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'Léxico y ortografía';

UPDATE public.curriculo_temas SET tema_en = 'Communication and advanced text types', tema_ru = 'Общение и продвинутые типы текстов'
WHERE curso = '4º ESO' AND asignatura = 'Valenciano' AND tema = 'Comunicació i tipologies textuals avançades';

UPDATE public.curriculo_temas SET tema_en = 'Contemporary Valencian literature', tema_ru = 'Современная валенсийская литература'
WHERE curso = '4º ESO' AND asignatura = 'Valenciano' AND tema = 'Literatura valenciana contemporànea';

UPDATE public.curriculo_temas SET tema_en = 'Advanced syntax', tema_ru = 'Продвинутый синтаксис'
WHERE curso = '4º ESO' AND asignatura = 'Valenciano' AND tema = 'Sintaxi avançada';

UPDATE public.curriculo_temas SET tema_en = 'Valencian vocabulary and spelling', tema_ru = 'Лексика и правописание валенсийского языка'
WHERE curso = '4º ESO' AND asignatura = 'Valenciano' AND tema = 'Lèxic i ortografia valenciana';

UPDATE public.curriculo_temas SET tema_en = 'Oral and written comprehension and production (early B2)', tema_ru = 'Понимание и продукция устной и письменной речи (начальный B2)'
WHERE curso = '4º ESO' AND asignatura = 'Inglés' AND tema = 'Comprensión y producción oral y escrita (B2 inicial)';

UPDATE public.curriculo_temas SET tema_en = 'Advanced communicative functions', tema_ru = 'Продвинутые коммуникативные функции'
WHERE curso = '4º ESO' AND asignatura = 'Inglés' AND tema = 'Funciones comunicativas avanzadas';

UPDATE public.curriculo_temas SET tema_en = 'Grammar and vocabulary for this level', tema_ru = 'Грамматика и словарный запас уровня'
WHERE curso = '4º ESO' AND asignatura = 'Inglés' AND tema = 'Gramática y léxico de nivel';

UPDATE public.curriculo_temas SET tema_en = 'Mediation strategies', tema_ru = 'Стратегии медиации'
WHERE curso = '4º ESO' AND asignatura = 'Inglés' AND tema = 'Estrategias de mediación';

UPDATE public.curriculo_temas SET tema_en = 'Sociocultural aspects', tema_ru = 'Социокультурные аспекты'
WHERE curso = '4º ESO' AND asignatura = 'Inglés' AND tema = 'Aspectos socioculturales';

UPDATE public.curriculo_temas SET tema_en = 'The 18th century and the liberal revolutions', tema_ru = 'XVIII век и либеральные революции'
WHERE curso = '4º ESO' AND asignatura = 'Geografía e Historia' AND tema = 'El siglo XVIII y las revoluciones liberales';

UPDATE public.curriculo_temas SET tema_en = 'The Industrial Revolution', tema_ru = 'Промышленная революция'
WHERE curso = '4º ESO' AND asignatura = 'Geografía e Historia' AND tema = 'La Revolución Industrial';

UPDATE public.curriculo_temas SET tema_en = 'Imperialism and the First World War', tema_ru = 'Империализм и Первая мировая война'
WHERE curso = '4º ESO' AND asignatura = 'Geografía e Historia' AND tema = 'Imperialismo y Primera Guerra Mundial';

UPDATE public.curriculo_temas SET tema_en = 'The interwar period and the Second World War', tema_ru = 'Межвоенный период и Вторая мировая война'
WHERE curso = '4º ESO' AND asignatura = 'Geografía e Historia' AND tema = 'Periodo de entreguerras y Segunda Guerra Mundial';

UPDATE public.curriculo_temas SET tema_en = 'The Cold War and decolonisation', tema_ru = 'Холодная война и деколонизация'
WHERE curso = '4º ESO' AND asignatura = 'Geografía e Historia' AND tema = 'Guerra Fría y descolonización';

UPDATE public.curriculo_temas SET tema_en = 'Contemporary Spain: 19th-20th centuries', tema_ru = 'Современная Испания: XIX-XX века'
WHERE curso = '4º ESO' AND asignatura = 'Geografía e Historia' AND tema = 'España contemporánea: siglos XIX-XX';

UPDATE public.curriculo_temas SET tema_en = 'Today''s world and globalisation', tema_ru = 'Современный мир и глобализация'
WHERE curso = '4º ESO' AND asignatura = 'Geografía e Historia' AND tema = 'El mundo actual y la globalización';

UPDATE public.curriculo_temas SET tema_en = 'Evolution and genetics', tema_ru = 'Эволюция и генетика'
WHERE curso = '4º ESO' AND asignatura = 'Biología y Geología' AND tema = 'La evolución y la genética';

UPDATE public.curriculo_temas SET tema_en = 'Molecular genetics and heredity', tema_ru = 'Молекулярная генетика и наследственность'
WHERE curso = '4º ESO' AND asignatura = 'Biología y Geología' AND tema = 'Genética molecular y herencia';

UPDATE public.curriculo_temas SET tema_en = 'The origin and evolution of living things', tema_ru = 'Происхождение и эволюция живых организмов'
WHERE curso = '4º ESO' AND asignatura = 'Biología y Geología' AND tema = 'Origen y evolución de los seres vivos';

UPDATE public.curriculo_temas SET tema_en = 'Ecology and the environment', tema_ru = 'Экология и окружающая среда'
WHERE curso = '4º ESO' AND asignatura = 'Biología y Geología' AND tema = 'Ecología y medio ambiente';

UPDATE public.curriculo_temas SET tema_en = 'Earth''s dynamics: plate tectonics', tema_ru = 'Динамика Земли: тектоника плит'
WHERE curso = '4º ESO' AND asignatura = 'Biología y Geología' AND tema = 'La dinámica de la Tierra: tectónica de placas';

UPDATE public.curriculo_temas SET tema_en = 'Earth''s history', tema_ru = 'История Земли'
WHERE curso = '4º ESO' AND asignatura = 'Biología y Geología' AND tema = 'Historia de la Tierra';

UPDATE public.curriculo_temas SET tema_en = 'Kinematics and dynamics: motion and forces', tema_ru = 'Кинематика и динамика: движение и силы'
WHERE curso = '4º ESO' AND asignatura = 'Física y Química' AND tema = 'Cinemática y dinámica: movimiento y fuerzas';

UPDATE public.curriculo_temas SET tema_en = 'Energy and work', tema_ru = 'Энергия и работа'
WHERE curso = '4º ESO' AND asignatura = 'Física y Química' AND tema = 'Energía y trabajo';

UPDATE public.curriculo_temas SET tema_en = 'Atomic structure and bonding', tema_ru = 'Строение атома и химическая связь'
WHERE curso = '4º ESO' AND asignatura = 'Física y Química' AND tema = 'Estructura atómica y enlace';

UPDATE public.curriculo_temas SET tema_en = 'Chemical reactions', tema_ru = 'Химические реакции'
WHERE curso = '4º ESO' AND asignatura = 'Física y Química' AND tema = 'Reacciones químicas';

UPDATE public.curriculo_temas SET tema_en = 'Carbon chemistry: an introduction', tema_ru = 'Химия углерода: введение'
WHERE curso = '4º ESO' AND asignatura = 'Física y Química' AND tema = 'Química del carbono: introducción';

UPDATE public.curriculo_temas SET tema_en = 'Economic activity and entrepreneurship', tema_ru = 'Экономическая деятельность и предпринимательство'
WHERE curso = '4º ESO' AND asignatura = 'Economía y Emprendimiento' AND tema = 'La actividad económica y el emprendimiento';

UPDATE public.curriculo_temas SET tema_en = 'Markets: supply and demand', tema_ru = 'Рынки: спрос и предложение'
WHERE curso = '4º ESO' AND asignatura = 'Economía y Emprendimiento' AND tema = 'Mercados: oferta y demanda';

UPDATE public.curriculo_temas SET tema_en = 'Personal and financial economics', tema_ru = 'Личная и финансовая экономика'
WHERE curso = '4º ESO' AND asignatura = 'Economía y Emprendimiento' AND tema = 'Economía personal y financiera';

UPDATE public.curriculo_temas SET tema_en = 'The entrepreneurial project', tema_ru = 'Предпринимательский проект'
WHERE curso = '4º ESO' AND asignatura = 'Economía y Emprendimiento' AND tema = 'El proyecto emprendedor';

UPDATE public.curriculo_temas SET tema_en = 'Latin and the Romance languages', tema_ru = 'Латинский язык и романские языки'
WHERE curso = '4º ESO' AND asignatura = 'Latín' AND tema = 'El latín y las lenguas romances';

UPDATE public.curriculo_temas SET tema_en = 'The Latin language system: basic morphology and syntax', tema_ru = 'Система латинского языка: основы морфологии и синтаксиса'
WHERE curso = '4º ESO' AND asignatura = 'Latín' AND tema = 'Sistema de la lengua latina: morfología y sintaxis básica';

UPDATE public.curriculo_temas SET tema_en = 'Latin texts and translation', tema_ru = 'Латинские тексты и перевод'
WHERE curso = '4º ESO' AND asignatura = 'Latín' AND tema = 'Textos latinos y traducción';

UPDATE public.curriculo_temas SET tema_en = 'Latin vocabulary and etymology', tema_ru = 'Латинская лексика и этимология'
WHERE curso = '4º ESO' AND asignatura = 'Latín' AND tema = 'Léxico y etimología latina';

UPDATE public.curriculo_temas SET tema_en = 'Roman civilisation', tema_ru = 'Римская цивилизация'
WHERE curso = '4º ESO' AND asignatura = 'Latín' AND tema = 'Civilización romana';

UPDATE public.curriculo_temas SET tema_en = 'Philosophical knowledge', tema_ru = 'Философское знание'
WHERE curso = '4º ESO' AND asignatura = 'Filosofía' AND tema = 'El saber filosófico';

UPDATE public.curriculo_temas SET tema_en = 'The human being', tema_ru = 'Человек'
WHERE curso = '4º ESO' AND asignatura = 'Filosofía' AND tema = 'El ser humano';

UPDATE public.curriculo_temas SET tema_en = 'Knowledge and truth', tema_ru = 'Знание и истина'
WHERE curso = '4º ESO' AND asignatura = 'Filosofía' AND tema = 'Conocimiento y verdad';

UPDATE public.curriculo_temas SET tema_en = 'Ethics and moral philosophy', tema_ru = 'Этика и моральная философия'
WHERE curso = '4º ESO' AND asignatura = 'Filosofía' AND tema = 'Ética y filosofía moral';

UPDATE public.curriculo_temas SET tema_en = 'Political philosophy', tema_ru = 'Политическая философия'
WHERE curso = '4º ESO' AND asignatura = 'Filosofía' AND tema = 'Filosofía política';

UPDATE public.curriculo_temas SET tema_en = 'Aesthetics: an introduction', tema_ru = 'Эстетика: введение'
WHERE curso = '4º ESO' AND asignatura = 'Filosofía' AND tema = 'Estética: introducción';

UPDATE public.curriculo_temas SET tema_en = 'Communication and text types', tema_ru = 'Общение и типы текстов'
WHERE curso = '1º Bachillerato' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'Comunicación y tipologías textuales';

UPDATE public.curriculo_temas SET tema_en = 'Varieties of Spanish', tema_ru = 'Варианты испанского языка'
WHERE curso = '1º Bachillerato' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'Variedades del español';

UPDATE public.curriculo_temas SET tema_en = 'Literature from the Middle Ages to the 19th century', tema_ru = 'Литература от Средневековья до XIX века'
WHERE curso = '1º Bachillerato' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'Literatura de la Edad Media al siglo XIX';

UPDATE public.curriculo_temas SET tema_en = 'Advanced syntax', tema_ru = 'Продвинутый синтаксис'
WHERE curso = '1º Bachillerato' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'Sintaxis avanzada';

UPDATE public.curriculo_temas SET tema_en = 'Norms and usage of Spanish', tema_ru = 'Нормы и употребление испанского языка'
WHERE curso = '1º Bachillerato' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'Norma y uso del español';

UPDATE public.curriculo_temas SET tema_en = 'Communication and academic texts', tema_ru = 'Общение и академические тексты'
WHERE curso = '1º Bachillerato' AND asignatura = 'Valenciano' AND tema = 'Comunicació i textos acadèmics';

UPDATE public.curriculo_temas SET tema_en = 'Sociolinguistics of Valencian', tema_ru = 'Социолингвистика валенсийского языка'
WHERE curso = '1º Bachillerato' AND asignatura = 'Valenciano' AND tema = 'Sociolingüística del valencià';

UPDATE public.curriculo_temas SET tema_en = 'Classical and contemporary Valencian literature', tema_ru = 'Классическая и современная валенсийская литература'
WHERE curso = '1º Bachillerato' AND asignatura = 'Valenciano' AND tema = 'Literatura valenciana clàssica i contemporànea';

UPDATE public.curriculo_temas SET tema_en = 'Text commentary', tema_ru = 'Анализ текста'
WHERE curso = '1º Bachillerato' AND asignatura = 'Valenciano' AND tema = 'Comentari de text';

UPDATE public.curriculo_temas SET tema_en = 'Comprehension and production of complex texts', tema_ru = 'Понимание и создание сложных текстов'
WHERE curso = '1º Bachillerato' AND asignatura = 'Inglés' AND tema = 'Comprensión y producción de textos complejos';

UPDATE public.curriculo_temas SET tema_en = 'Linguistic and intercultural mediation', tema_ru = 'Языковая и межкультурная медиация'
WHERE curso = '1º Bachillerato' AND asignatura = 'Inglés' AND tema = 'Mediación lingüística e intercultural';

UPDATE public.curriculo_temas SET tema_en = 'Grammar and vocabulary B1-B2', tema_ru = 'Грамматика и словарный запас B1-B2'
WHERE curso = '1º Bachillerato' AND asignatura = 'Inglés' AND tema = 'Gramática y léxico B1-B2';

UPDATE public.curriculo_temas SET tema_en = 'Sociocultural aspects', tema_ru = 'Социокультурные аспекты'
WHERE curso = '1º Bachillerato' AND asignatura = 'Inglés' AND tema = 'Aspectos socioculturales';

UPDATE public.curriculo_temas SET tema_en = 'What philosophy is', tema_ru = 'Что такое философия'
WHERE curso = '1º Bachillerato' AND asignatura = 'Filosofía' AND tema = 'Qué es la filosofía';

UPDATE public.curriculo_temas SET tema_en = 'Logic and argumentation', tema_ru = 'Логика и аргументация'
WHERE curso = '1º Bachillerato' AND asignatura = 'Filosofía' AND tema = 'Lógica y argumentación';

UPDATE public.curriculo_temas SET tema_en = 'Theory of knowledge', tema_ru = 'Теория познания'
WHERE curso = '1º Bachillerato' AND asignatura = 'Filosofía' AND tema = 'Teoría del conocimiento';

UPDATE public.curriculo_temas SET tema_en = 'Metaphysics', tema_ru = 'Метафизика'
WHERE curso = '1º Bachillerato' AND asignatura = 'Filosofía' AND tema = 'Metafísica';

UPDATE public.curriculo_temas SET tema_en = 'Philosophical anthropology', tema_ru = 'Философская антропология'
WHERE curso = '1º Bachillerato' AND asignatura = 'Filosofía' AND tema = 'Antropología filosófica';

UPDATE public.curriculo_temas SET tema_en = 'Ethics', tema_ru = 'Этика'
WHERE curso = '1º Bachillerato' AND asignatura = 'Filosofía' AND tema = 'Ética';

UPDATE public.curriculo_temas SET tema_en = 'Political philosophy', tema_ru = 'Политическая философия'
WHERE curso = '1º Bachillerato' AND asignatura = 'Filosofía' AND tema = 'Filosofía política';

UPDATE public.curriculo_temas SET tema_en = 'Aesthetics', tema_ru = 'Эстетика'
WHERE curso = '1º Bachillerato' AND asignatura = 'Filosofía' AND tema = 'Estética';

UPDATE public.curriculo_temas SET tema_en = 'Real numbers, complex numbers and logarithms', tema_ru = 'Действительные числа, комплексные числа и логарифмы'
WHERE curso = '1º Bachillerato' AND asignatura = 'Matemáticas' AND tema = 'Números reales, complejos y logaritmos';

UPDATE public.curriculo_temas SET tema_en = 'Algebra and equations', tema_ru = 'Алгебра и уравнения'
WHERE curso = '1º Bachillerato' AND asignatura = 'Matemáticas' AND tema = 'Álgebra y ecuaciones';

UPDATE public.curriculo_temas SET tema_en = 'Trigonometry', tema_ru = 'Тригонометрия'
WHERE curso = '1º Bachillerato' AND asignatura = 'Matemáticas' AND tema = 'Trigonometría';

UPDATE public.curriculo_temas SET tema_en = 'Plane analytic geometry', tema_ru = 'Плоская аналитическая геометрия'
WHERE curso = '1º Bachillerato' AND asignatura = 'Matemáticas' AND tema = 'Geometría analítica plana';

UPDATE public.curriculo_temas SET tema_en = 'Functions, limits and derivatives: an introduction', tema_ru = 'Функции, пределы и производные: введение'
WHERE curso = '1º Bachillerato' AND asignatura = 'Matemáticas' AND tema = 'Funciones, límites y derivadas: introducción';

UPDATE public.curriculo_temas SET tema_en = 'Two-dimensional statistics and probability', tema_ru = 'Двумерная статистика и вероятность'
WHERE curso = '1º Bachillerato' AND asignatura = 'Matemáticas' AND tema = 'Estadística bidimensional y probabilidad';

UPDATE public.curriculo_temas SET tema_en = 'Real numbers and financial mathematics', tema_ru = 'Действительные числа и финансовая математика'
WHERE curso = '1º Bachillerato' AND asignatura = 'Matemáticas Aplicadas' AND tema = 'Números reales y matemática financiera';

UPDATE public.curriculo_temas SET tema_en = 'Algebra: matrices, systems and linear programming', tema_ru = 'Алгебра: матрицы, системы и линейное программирование'
WHERE curso = '1º Bachillerato' AND asignatura = 'Matemáticas Aplicadas' AND tema = 'Álgebra: matrices, sistemas y programación lineal';

UPDATE public.curriculo_temas SET tema_en = 'Functions, limits and derivatives', tema_ru = 'Функции, пределы и производные'
WHERE curso = '1º Bachillerato' AND asignatura = 'Matemáticas Aplicadas' AND tema = 'Funciones, límites y derivadas';

UPDATE public.curriculo_temas SET tema_en = 'Descriptive statistics', tema_ru = 'Описательная статистика'
WHERE curso = '1º Bachillerato' AND asignatura = 'Matemáticas Aplicadas' AND tema = 'Estadística descriptiva';

UPDATE public.curriculo_temas SET tema_en = 'Probability', tema_ru = 'Вероятность'
WHERE curso = '1º Bachillerato' AND asignatura = 'Matemáticas Aplicadas' AND tema = 'Probabilidad';

UPDATE public.curriculo_temas SET tema_en = 'The crisis of the Ancien Régime and the liberal revolutions', tema_ru = 'Кризис Старого порядка и либеральные революции'
WHERE curso = '1º Bachillerato' AND asignatura = 'Historia del Mundo Contemporáneo' AND tema = 'Crisis del Antiguo Régimen y revoluciones liberales';

UPDATE public.curriculo_temas SET tema_en = 'The Industrial Revolution', tema_ru = 'Промышленная революция'
WHERE curso = '1º Bachillerato' AND asignatura = 'Historia del Mundo Contemporáneo' AND tema = 'Revolución Industrial';

UPDATE public.curriculo_temas SET tema_en = 'Imperialism', tema_ru = 'Империализм'
WHERE curso = '1º Bachillerato' AND asignatura = 'Historia del Mundo Contemporáneo' AND tema = 'Imperialismo';

UPDATE public.curriculo_temas SET tema_en = 'The world wars and the interwar period', tema_ru = 'Мировые войны и межвоенный период'
WHERE curso = '1º Bachillerato' AND asignatura = 'Historia del Mundo Contemporáneo' AND tema = 'Las guerras mundiales y el periodo de entreguerras';

UPDATE public.curriculo_temas SET tema_en = 'The Cold War', tema_ru = 'Холодная война'
WHERE curso = '1º Bachillerato' AND asignatura = 'Historia del Mundo Contemporáneo' AND tema = 'Guerra Fría';

UPDATE public.curriculo_temas SET tema_en = 'Decolonisation', tema_ru = 'Деколонизация'
WHERE curso = '1º Bachillerato' AND asignatura = 'Historia del Mundo Contemporáneo' AND tema = 'Descolonización';

UPDATE public.curriculo_temas SET tema_en = 'Today''s world and globalisation', tema_ru = 'Современный мир и глобализация'
WHERE curso = '1º Bachillerato' AND asignatura = 'Historia del Mundo Contemporáneo' AND tema = 'El mundo actual y la globalización';

UPDATE public.curriculo_temas SET tema_en = 'Scarcity and opportunity costs', tema_ru = 'Дефицит и издержки возможностей'
WHERE curso = '1º Bachillerato' AND asignatura = 'Economía' AND tema = 'Escasez y costes de oportunidad';

UPDATE public.curriculo_temas SET tema_en = 'Economic systems', tema_ru = 'Экономические системы'
WHERE curso = '1º Bachillerato' AND asignatura = 'Economía' AND tema = 'Sistemas económicos';

UPDATE public.curriculo_temas SET tema_en = 'Supply, demand and markets', tema_ru = 'Спрос, предложение и рынки'
WHERE curso = '1º Bachillerato' AND asignatura = 'Economía' AND tema = 'Oferta, demanda y mercados';

UPDATE public.curriculo_temas SET tema_en = 'GDP and national income', tema_ru = 'ВВП и национальный доход'
WHERE curso = '1º Bachillerato' AND asignatura = 'Economía' AND tema = 'PIB y renta nacional';

UPDATE public.curriculo_temas SET tema_en = 'Inflation and unemployment', tema_ru = 'Инфляция и безработица'
WHERE curso = '1º Bachillerato' AND asignatura = 'Economía' AND tema = 'Inflación y desempleo';

UPDATE public.curriculo_temas SET tema_en = 'Fiscal and monetary policy', tema_ru = 'Фискальная и денежно-кредитная политика'
WHERE curso = '1º Bachillerato' AND asignatura = 'Economía' AND tema = 'Política fiscal y monetaria';

UPDATE public.curriculo_temas SET tema_en = 'International trade and globalisation', tema_ru = 'Международная торговля и глобализация'
WHERE curso = '1º Bachillerato' AND asignatura = 'Economía' AND tema = 'Comercio internacional y globalización';

UPDATE public.curriculo_temas SET tema_en = 'The Spanish and Valencian economy', tema_ru = 'Экономика Испании и Валенсийского сообщества'
WHERE curso = '1º Bachillerato' AND asignatura = 'Economía' AND tema = 'Economía española y valenciana';

UPDATE public.curriculo_temas SET tema_en = 'First-person literature and lyric poetry', tema_ru = 'Литература от первого лица и лирическая поэзия'
WHERE curso = '1º Bachillerato' AND asignatura = 'Literatura Universal' AND tema = 'Literatura del yo y poesía lírica';

UPDATE public.curriculo_temas SET tema_en = 'Theatre and its genres', tema_ru = 'Театр и его жанры'
WHERE curso = '1º Bachillerato' AND asignatura = 'Literatura Universal' AND tema = 'El teatro y sus géneros';

UPDATE public.curriculo_temas SET tema_en = 'The real and the fantastic in narrative fiction', tema_ru = 'Реальное и фантастическое в повествовании'
WHERE curso = '1º Bachillerato' AND asignatura = 'Literatura Universal' AND tema = 'Lo real y lo fantástico en la narrativa';

UPDATE public.curriculo_temas SET tema_en = 'Intertextual thematic journeys', tema_ru = 'Межтекстовые тематические маршруты'
WHERE curso = '1º Bachillerato' AND asignatura = 'Literatura Universal' AND tema = 'Itinerarios temáticos intertextuales';

UPDATE public.curriculo_temas SET tema_en = 'Literature and its relationship with other arts', tema_ru = 'Связь литературы с другими видами искусства'
WHERE curso = '1º Bachillerato' AND asignatura = 'Literatura Universal' AND tema = 'Relaciones literatura-otras artes';

UPDATE public.curriculo_temas SET tema_en = 'Students'' own literary creation', tema_ru = 'Собственное литературное творчество'
WHERE curso = '1º Bachillerato' AND asignatura = 'Literatura Universal' AND tema = 'Creación literaria propia';

UPDATE public.curriculo_temas SET tema_en = 'Phonetics, nominal and verbal morphology', tema_ru = 'Фонетика, морфология имени и глагола'
WHERE curso = '1º Bachillerato' AND asignatura = 'Latín' AND tema = 'Fonética, morfología nominal y verbal';

UPDATE public.curriculo_temas SET tema_en = 'The syntax of cases and sentences', tema_ru = 'Синтаксис падежей и предложений'
WHERE curso = '1º Bachillerato' AND asignatura = 'Latín' AND tema = 'Sintaxis de casos y oraciones';

UPDATE public.curriculo_temas SET tema_en = 'Translation of graded texts', tema_ru = 'Перевод адаптированных текстов'
WHERE curso = '1º Bachillerato' AND asignatura = 'Latín' AND tema = 'Traducción de textos graduados';

UPDATE public.curriculo_temas SET tema_en = 'Latin roots and Latinisms', tema_ru = 'Латинские корни и латинизмы'
WHERE curso = '1º Bachillerato' AND asignatura = 'Latín' AND tema = 'Étimos y latinismos';

UPDATE public.curriculo_temas SET tema_en = 'Latin literature', tema_ru = 'Латинская литература'
WHERE curso = '1º Bachillerato' AND asignatura = 'Latín' AND tema = 'Literatura latina';

UPDATE public.curriculo_temas SET tema_en = 'Roman civilisation and its legacy', tema_ru = 'Римская цивилизация и её наследие'
WHERE curso = '1º Bachillerato' AND asignatura = 'Latín' AND tema = 'Civilización romana y su pervivencia';

UPDATE public.curriculo_temas SET tema_en = 'The alphabet, phonetics and accentuation', tema_ru = 'Алфавит, фонетика и акцентуация'
WHERE curso = '1º Bachillerato' AND asignatura = 'Griego' AND tema = 'Alfabeto, fonética y acentuación';

UPDATE public.curriculo_temas SET tema_en = 'Nominal and verbal inflection', tema_ru = 'Склонение имён и спряжение глаголов'
WHERE curso = '1º Bachillerato' AND asignatura = 'Griego' AND tema = 'Flexión nominal y verbal';

UPDATE public.curriculo_temas SET tema_en = 'Greek syntax', tema_ru = 'Греческий синтаксис'
WHERE curso = '1º Bachillerato' AND asignatura = 'Griego' AND tema = 'Sintaxis griega';

UPDATE public.curriculo_temas SET tema_en = 'Text translation', tema_ru = 'Перевод текстов'
WHERE curso = '1º Bachillerato' AND asignatura = 'Griego' AND tema = 'Traducción de textos';

UPDATE public.curriculo_temas SET tema_en = 'The history and society of Greece', tema_ru = 'История и общество Греции'
WHERE curso = '1º Bachillerato' AND asignatura = 'Griego' AND tema = 'Historia y sociedad de Grecia';

UPDATE public.curriculo_temas SET tema_en = 'Mythology', tema_ru = 'Мифология'
WHERE curso = '1º Bachillerato' AND asignatura = 'Griego' AND tema = 'Mitología';

UPDATE public.curriculo_temas SET tema_en = 'Hellenisms and scientific etymology', tema_ru = 'Грецизмы и научная этимология'
WHERE curso = '1º Bachillerato' AND asignatura = 'Griego' AND tema = 'Helenismos y etimología científica';

UPDATE public.curriculo_temas SET tema_en = 'Drawing instruments and CAD', tema_ru = 'Чертёжные инструменты и CAD'
WHERE curso = '1º Bachillerato' AND asignatura = 'Dibujo Técnico' AND tema = 'Instrumental y CAD';

UPDATE public.curriculo_temas SET tema_en = 'Geometric constructions, tangencies and conic curves', tema_ru = 'Геометрические построения, касания и конические кривые'
WHERE curso = '1º Bachillerato' AND asignatura = 'Dibujo Técnico' AND tema = 'Trazados geométricos, tangencias y curvas cónicas';

UPDATE public.curriculo_temas SET tema_en = 'Orthographic (dihedral) projection', tema_ru = 'Ортогональное (двугранное) проецирование'
WHERE curso = '1º Bachillerato' AND asignatura = 'Dibujo Técnico' AND tema = 'Sistema diédrico';

UPDATE public.curriculo_temas SET tema_en = 'Axonometric projection', tema_ru = 'Аксонометрическая проекция'
WHERE curso = '1º Bachillerato' AND asignatura = 'Dibujo Técnico' AND tema = 'Sistema axonométrico';

UPDATE public.curriculo_temas SET tema_en = 'Perspective (conic) projection', tema_ru = 'Перспективная (коническая) проекция'
WHERE curso = '1º Bachillerato' AND asignatura = 'Dibujo Técnico' AND tema = 'Sistema cónico';

UPDATE public.curriculo_temas SET tema_en = 'Drawing in the history of art', tema_ru = 'Рисунок в истории искусства'
WHERE curso = '1º Bachillerato' AND asignatura = 'Dibujo Artístico' AND tema = 'El dibujo en la historia del arte';

UPDATE public.curriculo_temas SET tema_en = 'Line, mark-making and texture', tema_ru = 'Линия, пятно и текстура'
WHERE curso = '1º Bachillerato' AND asignatura = 'Dibujo Artístico' AND tema = 'Línea, mancha y textura';

UPDATE public.curriculo_temas SET tema_en = 'Framing and life drawing', tema_ru = 'Кадрирование и рисование с натуры'
WHERE curso = '1º Bachillerato' AND asignatura = 'Dibujo Artístico' AND tema = 'Encuadre y dibujo del natural';

UPDATE public.curriculo_temas SET tema_en = 'The human figure', tema_ru = 'Человеческая фигура'
WHERE curso = '1º Bachillerato' AND asignatura = 'Dibujo Artístico' AND tema = 'La figura humana';

UPDATE public.curriculo_temas SET tema_en = 'Light, chiaroscuro and perspective', tema_ru = 'Свет, светотень и перспектива'
WHERE curso = '1º Bachillerato' AND asignatura = 'Dibujo Artístico' AND tema = 'Luz, claroscuro y perspectiva';

UPDATE public.curriculo_temas SET tema_en = 'Colour in drawing', tema_ru = 'Цвет в рисунке'
WHERE curso = '1º Bachillerato' AND asignatura = 'Dibujo Artístico' AND tema = 'Color en el dibujo';

UPDATE public.curriculo_temas SET tema_en = 'Art project', tema_ru = 'Художественный проект'
WHERE curso = '1º Bachillerato' AND asignatura = 'Dibujo Artístico' AND tema = 'Proyecto artístico';

UPDATE public.curriculo_temas SET tema_en = 'Sculptural techniques and materials', tema_ru = 'Скульптурные техники и материалы'
WHERE curso = '1º Bachillerato' AND asignatura = 'Volumen' AND tema = 'Técnicas y materiales escultóricos';

UPDATE public.curriculo_temas SET tema_en = 'Line, plane and three-dimensional forms', tema_ru = 'Линия, плоскость и трёхмерные формы'
WHERE curso = '1º Bachillerato' AND asignatura = 'Volumen' AND tema = 'Línea, plano y formas tridimensionales';

UPDATE public.curriculo_temas SET tema_en = 'Contemporary sculpture: Land Art, Arte Povera, installation', tema_ru = 'Современная скульптура: лэнд-арт, арте повера, инсталляция'
WHERE curso = '1º Bachillerato' AND asignatura = 'Volumen' AND tema = 'Escultura contemporánea: Land-Art, Arte Povera, instalación';

UPDATE public.curriculo_temas SET tema_en = 'Void, light and movement', tema_ru = 'Пустота, свет и движение'
WHERE curso = '1º Bachillerato' AND asignatura = 'Volumen' AND tema = 'El vacío, la luz y el movimiento';

UPDATE public.curriculo_temas SET tema_en = 'Three-dimensional projects', tema_ru = 'Трёхмерные проекты'
WHERE curso = '1º Bachillerato' AND asignatura = 'Volumen' AND tema = 'Proyectos tridimensionales';

UPDATE public.curriculo_temas SET tema_en = 'The history of photography and cinema', tema_ru = 'История фотографии и кино'
WHERE curso = '1º Bachillerato' AND asignatura = 'Cultura Audiovisual' AND tema = 'Historia de la fotografía y del cine';

UPDATE public.curriculo_temas SET tema_en = 'Audiovisual language and codes', tema_ru = 'Язык и коды аудиовизуальных произведений'
WHERE curso = '1º Bachillerato' AND asignatura = 'Cultura Audiovisual' AND tema = 'Lenguaje y códigos audiovisuales';

UPDATE public.curriculo_temas SET tema_en = 'Formal and expressive elements of the image', tema_ru = 'Формальные и выразительные элементы изображения'
WHERE curso = '1º Bachillerato' AND asignatura = 'Cultura Audiovisual' AND tema = 'Elementos formales y expresivos de la imagen';

UPDATE public.curriculo_temas SET tema_en = 'Audiovisual narrative and screenwriting', tema_ru = 'Аудиовизуальное повествование и сценарий'
WHERE curso = '1º Bachillerato' AND asignatura = 'Cultura Audiovisual' AND tema = 'Narrativa audiovisual y guion';

UPDATE public.curriculo_temas SET tema_en = 'Audiovisual production by stages', tema_ru = 'Аудиовизуальное производство по этапам'
WHERE curso = '1º Bachillerato' AND asignatura = 'Cultura Audiovisual' AND tema = 'Producción audiovisual por fases';

UPDATE public.curriculo_temas SET tema_en = 'Critical analysis of audiovisual messages', tema_ru = 'Критический анализ аудиовизуальных сообщений'
WHERE curso = '1º Bachillerato' AND asignatura = 'Cultura Audiovisual' AND tema = 'Análisis crítico de mensajes audiovisuales';

UPDATE public.curriculo_temas SET tema_en = 'The text and its properties', tema_ru = 'Текст и его свойства'
WHERE curso = '2º Bachillerato' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'El texto y sus propiedades';

UPDATE public.curriculo_temas SET tema_en = '20th- and 21st-century literature', tema_ru = 'Литература XX-XXI веков'
WHERE curso = '2º Bachillerato' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'Literatura del siglo XX y XXI';

UPDATE public.curriculo_temas SET tema_en = 'Text commentary', tema_ru = 'Анализ текста'
WHERE curso = '2º Bachillerato' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'Comentario de texto';

UPDATE public.curriculo_temas SET tema_en = 'Norms and usage of Spanish', tema_ru = 'Нормы и употребление испанского языка'
WHERE curso = '2º Bachillerato' AND asignatura = 'Lengua Castellana y Literatura' AND tema = 'Norma y uso del español';

UPDATE public.curriculo_temas SET tema_en = 'The text and its properties', tema_ru = 'Текст и его свойства'
WHERE curso = '2º Bachillerato' AND asignatura = 'Valenciano' AND tema = 'El text i les seues propietats';

UPDATE public.curriculo_temas SET tema_en = '20th- and 21st-century Valencian literature', tema_ru = 'Валенсийская литература XX-XXI веков'
WHERE curso = '2º Bachillerato' AND asignatura = 'Valenciano' AND tema = 'Literatura valenciana del segle XX i XXI';

UPDATE public.curriculo_temas SET tema_en = 'Text commentary', tema_ru = 'Анализ текста'
WHERE curso = '2º Bachillerato' AND asignatura = 'Valenciano' AND tema = 'Comentari de text';

UPDATE public.curriculo_temas SET tema_en = 'Norms and usage of Valencian', tema_ru = 'Нормы и употребление валенсийского языка'
WHERE curso = '2º Bachillerato' AND asignatura = 'Valenciano' AND tema = 'Norma i ús del valencià';

UPDATE public.curriculo_temas SET tema_en = 'Comprehension and production of complex texts (B2-C1)', tema_ru = 'Понимание и создание сложных текстов (B2-C1)'
WHERE curso = '2º Bachillerato' AND asignatura = 'Inglés' AND tema = 'Comprensión y producción de textos complejos (B2-C1)';

UPDATE public.curriculo_temas SET tema_en = 'Advanced mediation', tema_ru = 'Продвинутая медиация'
WHERE curso = '2º Bachillerato' AND asignatura = 'Inglés' AND tema = 'Mediación avanzada';

UPDATE public.curriculo_temas SET tema_en = 'Advanced-level grammar and vocabulary', tema_ru = 'Грамматика и словарный запас продвинутого уровня'
WHERE curso = '2º Bachillerato' AND asignatura = 'Inglés' AND tema = 'Gramática y léxico de nivel avanzado';

UPDATE public.curriculo_temas SET tema_en = 'Comparative sociocultural aspects', tema_ru = 'Сравнительные социокультурные аспекты'
WHERE curso = '2º Bachillerato' AND asignatura = 'Inglés' AND tema = 'Aspectos socioculturales comparados';

UPDATE public.curriculo_temas SET tema_en = 'Spain''s historical roots up to the 18th century', tema_ru = 'Исторические корни Испании до XVIII века'
WHERE curso = '2º Bachillerato' AND asignatura = 'Historia de España' AND tema = 'Raíces históricas de España hasta el siglo XVIII';

UPDATE public.curriculo_temas SET tema_en = 'The 19th century: Liberalism and the Restoration', tema_ru = 'XIX век: либерализм и Реставрация'
WHERE curso = '2º Bachillerato' AND asignatura = 'Historia de España' AND tema = 'El siglo XIX: liberalismo y Restauración';

UPDATE public.curriculo_temas SET tema_en = 'The 20th century: the Second Republic and the Civil War', tema_ru = 'XX век: Вторая республика и гражданская война'
WHERE curso = '2º Bachillerato' AND asignatura = 'Historia de España' AND tema = 'El siglo XX: II República y Guerra Civil';

UPDATE public.curriculo_temas SET tema_en = 'The Franco dictatorship', tema_ru = 'Франкизм'
WHERE curso = '2º Bachillerato' AND asignatura = 'Historia de España' AND tema = 'El franquismo';

UPDATE public.curriculo_temas SET tema_en = 'The Transition and democratic Spain', tema_ru = 'Переход к демократии и демократическая Испания'
WHERE curso = '2º Bachillerato' AND asignatura = 'Historia de España' AND tema = 'La Transición y la España democrática';

UPDATE public.curriculo_temas SET tema_en = 'Historical method and the use of sources', tema_ru = 'Исторический метод и работа с источниками'
WHERE curso = '2º Bachillerato' AND asignatura = 'Historia de España' AND tema = 'Método histórico y uso de fuentes';

UPDATE public.curriculo_temas SET tema_en = 'Matrices and determinants', tema_ru = 'Матрицы и определители'
WHERE curso = '2º Bachillerato' AND asignatura = 'Matemáticas' AND tema = 'Matrices y determinantes';

UPDATE public.curriculo_temas SET tema_en = 'Systems of equations', tema_ru = 'Системы уравнений'
WHERE curso = '2º Bachillerato' AND asignatura = 'Matemáticas' AND tema = 'Sistemas de ecuaciones';

UPDATE public.curriculo_temas SET tema_en = 'Geometry in space: vectors', tema_ru = 'Геометрия в пространстве: векторы'
WHERE curso = '2º Bachillerato' AND asignatura = 'Matemáticas' AND tema = 'Geometría en el espacio: vectores';

UPDATE public.curriculo_temas SET tema_en = 'Limits, continuity and derivatives', tema_ru = 'Пределы, непрерывность и производные'
WHERE curso = '2º Bachillerato' AND asignatura = 'Matemáticas' AND tema = 'Límites, continuidad y derivadas';

UPDATE public.curriculo_temas SET tema_en = 'Integrals', tema_ru = 'Интегралы'
WHERE curso = '2º Bachillerato' AND asignatura = 'Matemáticas' AND tema = 'Integrales';

UPDATE public.curriculo_temas SET tema_en = 'Probability and distributions', tema_ru = 'Вероятность и распределения'
WHERE curso = '2º Bachillerato' AND asignatura = 'Matemáticas' AND tema = 'Probabilidad y distribuciones';

UPDATE public.curriculo_temas SET tema_en = 'Matrices and linear programming', tema_ru = 'Матрицы и линейное программирование'
WHERE curso = '2º Bachillerato' AND asignatura = 'Matemáticas Aplicadas' AND tema = 'Matrices y programación lineal';

UPDATE public.curriculo_temas SET tema_en = 'Analysis: applied derivatives and integrals', tema_ru = 'Анализ: прикладные производные и интегралы'
WHERE curso = '2º Bachillerato' AND asignatura = 'Matemáticas Aplicadas' AND tema = 'Análisis: derivadas e integrales aplicadas';

UPDATE public.curriculo_temas SET tema_en = 'Two-dimensional statistics', tema_ru = 'Двумерная статистика'
WHERE curso = '2º Bachillerato' AND asignatura = 'Matemáticas Aplicadas' AND tema = 'Estadística bidimensional';

UPDATE public.curriculo_temas SET tema_en = 'Probability and statistical inference', tema_ru = 'Вероятность и статистический вывод'
WHERE curso = '2º Bachillerato' AND asignatura = 'Matemáticas Aplicadas' AND tema = 'Probabilidad e inferencia estadística';

UPDATE public.curriculo_temas SET tema_en = 'Universal gravitation and orbital motion', tema_ru = 'Всемирная гравитация и орбитальное движение'
WHERE curso = '2º Bachillerato' AND asignatura = 'Física' AND tema = 'Gravitación universal y movimiento orbital';

UPDATE public.curriculo_temas SET tema_en = 'Electric field and magnetic field', tema_ru = 'Электрическое и магнитное поля'
WHERE curso = '2º Bachillerato' AND asignatura = 'Física' AND tema = 'Campo eléctrico y campo magnético';

UPDATE public.curriculo_temas SET tema_en = 'Electromagnetic induction', tema_ru = 'Электромагнитная индукция'
WHERE curso = '2º Bachillerato' AND asignatura = 'Física' AND tema = 'Inducción electromagnética';

UPDATE public.curriculo_temas SET tema_en = 'Wave motion and sound', tema_ru = 'Волновое движение и звук'
WHERE curso = '2º Bachillerato' AND asignatura = 'Física' AND tema = 'Movimiento ondulatorio y sonido';

UPDATE public.curriculo_temas SET tema_en = 'Geometric optics', tema_ru = 'Геометрическая оптика'
WHERE curso = '2º Bachillerato' AND asignatura = 'Física' AND tema = 'Óptica geométrica';

UPDATE public.curriculo_temas SET tema_en = 'Special relativity', tema_ru = 'Специальная теория относительности'
WHERE curso = '2º Bachillerato' AND asignatura = 'Física' AND tema = 'Relatividad especial';

UPDATE public.curriculo_temas SET tema_en = 'Quantum physics', tema_ru = 'Квантовая физика'
WHERE curso = '2º Bachillerato' AND asignatura = 'Física' AND tema = 'Física cuántica';

UPDATE public.curriculo_temas SET tema_en = 'Nuclear and particle physics', tema_ru = 'Ядерная физика и физика частиц'
WHERE curso = '2º Bachillerato' AND asignatura = 'Física' AND tema = 'Física nuclear y de partículas';

UPDATE public.curriculo_temas SET tema_en = 'Atomic structure and the periodic table', tema_ru = 'Строение атома и периодическая таблица'
WHERE curso = '2º Bachillerato' AND asignatura = 'Química' AND tema = 'Estructura atómica y sistema periódico';

UPDATE public.curriculo_temas SET tema_en = 'Chemical bonding', tema_ru = 'Химическая связь'
WHERE curso = '2º Bachillerato' AND asignatura = 'Química' AND tema = 'Enlace químico';

UPDATE public.curriculo_temas SET tema_en = 'Thermochemistry', tema_ru = 'Термохимия'
WHERE curso = '2º Bachillerato' AND asignatura = 'Química' AND tema = 'Termoquímica';

UPDATE public.curriculo_temas SET tema_en = 'Chemical kinetics', tema_ru = 'Химическая кинетика'
WHERE curso = '2º Bachillerato' AND asignatura = 'Química' AND tema = 'Cinética química';

UPDATE public.curriculo_temas SET tema_en = 'Chemical equilibrium', tema_ru = 'Химическое равновесие'
WHERE curso = '2º Bachillerato' AND asignatura = 'Química' AND tema = 'Equilibrio químico';

UPDATE public.curriculo_temas SET tema_en = 'Acid-base reactions', tema_ru = 'Кислотно-основные реакции'
WHERE curso = '2º Bachillerato' AND asignatura = 'Química' AND tema = 'Reacciones ácido-base';

UPDATE public.curriculo_temas SET tema_en = 'Redox reactions', tema_ru = 'Окислительно-восстановительные реакции'
WHERE curso = '2º Bachillerato' AND asignatura = 'Química' AND tema = 'Reacciones redox';

UPDATE public.curriculo_temas SET tema_en = 'Organic chemistry and polymers', tema_ru = 'Органическая химия и полимеры'
WHERE curso = '2º Bachillerato' AND asignatura = 'Química' AND tema = 'Química orgánica y polímeros';

UPDATE public.curriculo_temas SET tema_en = 'The molecular basis of life: carbohydrates, lipids, proteins, nucleic acids', tema_ru = 'Молекулярные основы жизни: углеводы, липиды, белки, нуклеиновые кислоты'
WHERE curso = '2º Bachillerato' AND asignatura = 'Biología' AND tema = 'La base molecular de la vida: glúcidos, lípidos, proteínas, ácidos nucleicos';

UPDATE public.curriculo_temas SET tema_en = 'The cell and its physiology', tema_ru = 'Клетка и её физиология'
WHERE curso = '2º Bachillerato' AND asignatura = 'Biología' AND tema = 'La célula y su fisiología';

UPDATE public.curriculo_temas SET tema_en = 'Metabolism: catabolism and anabolism', tema_ru = 'Обмен веществ: катаболизм и анаболизм'
WHERE curso = '2º Bachillerato' AND asignatura = 'Biología' AND tema = 'Metabolismo: catabolismo y anabolismo';

UPDATE public.curriculo_temas SET tema_en = 'Molecular genetics', tema_ru = 'Молекулярная генетика'
WHERE curso = '2º Bachillerato' AND asignatura = 'Biología' AND tema = 'Genética molecular';

UPDATE public.curriculo_temas SET tema_en = 'Microbiology', tema_ru = 'Микробиология'
WHERE curso = '2º Bachillerato' AND asignatura = 'Biología' AND tema = 'Microbiología';

UPDATE public.curriculo_temas SET tema_en = 'Immunology', tema_ru = 'Иммунология'
WHERE curso = '2º Bachillerato' AND asignatura = 'Biología' AND tema = 'Inmunología';

UPDATE public.curriculo_temas SET tema_en = 'Methods of geological work', tema_ru = 'Методы геологической работы'
WHERE curso = '2º Bachillerato' AND asignatura = 'Geología y Ciencias Ambientales' AND tema = 'Métodos del trabajo geológico';

UPDATE public.curriculo_temas SET tema_en = 'Plate tectonics and rock deformation', tema_ru = 'Тектоника плит и деформация пород'
WHERE curso = '2º Bachillerato' AND asignatura = 'Geología y Ciencias Ambientales' AND tema = 'Tectónica de placas y deformación de rocas';

UPDATE public.curriculo_temas SET tema_en = 'Natural hazards', tema_ru = 'Природные риски'
WHERE curso = '2º Bachillerato' AND asignatura = 'Geología y Ciencias Ambientales' AND tema = 'Riesgos naturales';

UPDATE public.curriculo_temas SET tema_en = 'The shaping of relief', tema_ru = 'Формирование рельефа'
WHERE curso = '2º Bachillerato' AND asignatura = 'Geología y Ciencias Ambientales' AND tema = 'Modelado del relieve';

UPDATE public.curriculo_temas SET tema_en = 'Atmosphere, hydrosphere and climate', tema_ru = 'Атмосфера, гидросфера и климат'
WHERE curso = '2º Bachillerato' AND asignatura = 'Geología y Ciencias Ambientales' AND tema = 'Atmósfera, hidrosfera y clima';

UPDATE public.curriculo_temas SET tema_en = 'Geological resources and their sustainable management', tema_ru = 'Геологические ресурсы и их устойчивое использование'
WHERE curso = '2º Bachillerato' AND asignatura = 'Geología y Ciencias Ambientales' AND tema = 'Recursos geológicos y su gestión sostenible';

UPDATE public.curriculo_temas SET tema_en = 'Standardisation, scales and dimensioning', tema_ru = 'Стандартизация, масштабы и нанесение размеров'
WHERE curso = '2º Bachillerato' AND asignatura = 'Dibujo Técnico' AND tema = 'Normalización, escalas y acotación';

UPDATE public.curriculo_temas SET tema_en = 'Advanced representation systems', tema_ru = 'Продвинутые системы проецирования'
WHERE curso = '2º Bachillerato' AND asignatura = 'Dibujo Técnico' AND tema = 'Sistemas de representación avanzados';

UPDATE public.curriculo_temas SET tema_en = 'Sketches and workshop drawings', tema_ru = 'Эскизы и рабочие чертежи'
WHERE curso = '2º Bachillerato' AND asignatura = 'Dibujo Técnico' AND tema = 'Croquis y planos de taller';

UPDATE public.curriculo_temas SET tema_en = 'Cartography and GIS', tema_ru = 'Картография и ГИС'
WHERE curso = '2º Bachillerato' AND asignatura = 'Geografía' AND tema = 'Cartografía y SIG';

UPDATE public.curriculo_temas SET tema_en = 'Spain''s relief, climate and landscapes', tema_ru = 'Рельеф, климат и ландшафты Испании'
WHERE curso = '2º Bachillerato' AND asignatura = 'Geografía' AND tema = 'Relieve, clima y paisajes de España';

UPDATE public.curriculo_temas SET tema_en = 'Water resources and the environment', tema_ru = 'Водные ресурсы и окружающая среда'
WHERE curso = '2º Bachillerato' AND asignatura = 'Geografía' AND tema = 'Recursos hídricos y medio ambiente';

UPDATE public.curriculo_temas SET tema_en = 'Population and cities', tema_ru = 'Население и города'
WHERE curso = '2º Bachillerato' AND asignatura = 'Geografía' AND tema = 'Población y ciudades';

UPDATE public.curriculo_temas SET tema_en = 'Economic sectors', tema_ru = 'Секторы экономики'
WHERE curso = '2º Bachillerato' AND asignatura = 'Geografía' AND tema = 'Sectores económicos';

UPDATE public.curriculo_temas SET tema_en = 'Spain in the EU', tema_ru = 'Испания в ЕС'
WHERE curso = '2º Bachillerato' AND asignatura = 'Geografía' AND tema = 'España en la UE';

UPDATE public.curriculo_temas SET tema_en = 'SDGs and sustainable development', tema_ru = 'ЦУР и устойчивое развитие'
WHERE curso = '2º Bachillerato' AND asignatura = 'Geografía' AND tema = 'ODS y desarrollo sostenible';

UPDATE public.curriculo_temas SET tema_en = 'The Presocratics, Plato and Aristotle', tema_ru = 'Досократики, Платон и Аристотель'
WHERE curso = '2º Bachillerato' AND asignatura = 'Historia de la Filosofía' AND tema = 'Presocráticos, Platón y Aristóteles';

UPDATE public.curriculo_temas SET tema_en = 'Hellenistic philosophy', tema_ru = 'Эллинистическая философия'
WHERE curso = '2º Bachillerato' AND asignatura = 'Historia de la Filosofía' AND tema = 'Filosofía helenística';

UPDATE public.curriculo_temas SET tema_en = 'Augustine and Thomas Aquinas', tema_ru = 'Августин и Фома Аквинский'
WHERE curso = '2º Bachillerato' AND asignatura = 'Historia de la Filosofía' AND tema = 'Agustín y Tomás de Aquino';

UPDATE public.curriculo_temas SET tema_en = 'Rationalism and empiricism', tema_ru = 'Рационализм и эмпиризм'
WHERE curso = '2º Bachillerato' AND asignatura = 'Historia de la Filosofía' AND tema = 'Racionalismo y empirismo';

UPDATE public.curriculo_temas SET tema_en = 'Kant and the Enlightenment', tema_ru = 'Кант и эпоха Просвещения'
WHERE curso = '2º Bachillerato' AND asignatura = 'Historia de la Filosofía' AND tema = 'Kant e Ilustración';

UPDATE public.curriculo_temas SET tema_en = 'Marx and Nietzsche', tema_ru = 'Маркс и Ницше'
WHERE curso = '2º Bachillerato' AND asignatura = 'Historia de la Filosofía' AND tema = 'Marx y Nietzsche';

UPDATE public.curriculo_temas SET tema_en = '20th-century philosophy and Spanish thought', tema_ru = 'Философия XX века и испанская мысль'
WHERE curso = '2º Bachillerato' AND asignatura = 'Historia de la Filosofía' AND tema = 'Filosofía del siglo XX y pensamiento español';

UPDATE public.curriculo_temas SET tema_en = 'The firm and the entrepreneur', tema_ru = 'Предприятие и предприниматель'
WHERE curso = '2º Bachillerato' AND asignatura = 'Empresa y Diseño de Modelos de Negocio' AND tema = 'La empresa y el emprendedor';

UPDATE public.curriculo_temas SET tema_en = 'The business environment and SWOT analysis', tema_ru = 'Деловая среда и SWOT-анализ'
WHERE curso = '2º Bachillerato' AND asignatura = 'Empresa y Diseño de Modelos de Negocio' AND tema = 'Entorno empresarial y análisis DAFO';

UPDATE public.curriculo_temas SET tema_en = 'Functional areas: production, sales, HR, finance', tema_ru = 'Функциональные области: производство, продажи, кадры, финансы'
WHERE curso = '2º Bachillerato' AND asignatura = 'Empresa y Diseño de Modelos de Negocio' AND tema = 'Áreas funcionales: producción, comercial, RRHH, financiera';

UPDATE public.curriculo_temas SET tema_en = 'Business models and innovation', tema_ru = 'Бизнес-модели и инновации'
WHERE curso = '2º Bachillerato' AND asignatura = 'Empresa y Diseño de Modelos de Negocio' AND tema = 'Modelos de negocio e innovación';

UPDATE public.curriculo_temas SET tema_en = 'Basic accounting and finance', tema_ru = 'Основы бухгалтерского учёта и финансов'
WHERE curso = '2º Bachillerato' AND asignatura = 'Empresa y Diseño de Modelos de Negocio' AND tema = 'Contabilidad y finanzas básicas';

UPDATE public.curriculo_temas SET tema_en = 'Terminology and analysis of the work of art', tema_ru = 'Терминология и анализ произведения искусства'
WHERE curso = '2º Bachillerato' AND asignatura = 'Historia del Arte' AND tema = 'Terminología y análisis de la obra de arte';

UPDATE public.curriculo_temas SET tema_en = 'Ancient art: Egypt, Greece, Rome', tema_ru = 'Искусство древности: Египет, Греция, Рим'
WHERE curso = '2º Bachillerato' AND asignatura = 'Historia del Arte' AND tema = 'Arte antiguo: Egipto, Grecia, Roma';

UPDATE public.curriculo_temas SET tema_en = 'Medieval art: Romanesque, Gothic, Islamic', tema_ru = 'Средневековое искусство: романское, готическое, исламское'
WHERE curso = '2º Bachillerato' AND asignatura = 'Historia del Arte' AND tema = 'Arte medieval: románico, gótico, islámico';

UPDATE public.curriculo_temas SET tema_en = 'The Renaissance and the Baroque', tema_ru = 'Ренессанс и барокко'
WHERE curso = '2º Bachillerato' AND asignatura = 'Historia del Arte' AND tema = 'Renacimiento y Barroco';

UPDATE public.curriculo_temas SET tema_en = 'Neoclassicism, Romanticism and the avant-garde', tema_ru = 'Неоклассицизм, романтизм и авангард'
WHERE curso = '2º Bachillerato' AND asignatura = 'Historia del Arte' AND tema = 'Neoclasicismo, Romanticismo y vanguardias';

UPDATE public.curriculo_temas SET tema_en = 'Contemporary and 21st-century art', tema_ru = 'Современное искусство и искусство XXI века'
WHERE curso = '2º Bachillerato' AND asignatura = 'Historia del Arte' AND tema = 'Arte contemporáneo y del siglo XXI';

UPDATE public.curriculo_temas SET tema_en = 'Advanced Latin morphology and syntax', tema_ru = 'Продвинутая морфология и синтаксис латинского языка'
WHERE curso = '2º Bachillerato' AND asignatura = 'Latín' AND tema = 'Morfología y sintaxis latinas avanzadas';

UPDATE public.curriculo_temas SET tema_en = 'Translation of Latin literary texts', tema_ru = 'Перевод латинских литературных текстов'
WHERE curso = '2º Bachillerato' AND asignatura = 'Latín' AND tema = 'Traducción de textos literarios latinos';

UPDATE public.curriculo_temas SET tema_en = 'Latin literature: main genres and authors', tema_ru = 'Латинская литература: основные жанры и авторы'
WHERE curso = '2º Bachillerato' AND asignatura = 'Latín' AND tema = 'Literatura latina: géneros y autores principales';

UPDATE public.curriculo_temas SET tema_en = 'Roman civilisation: the legacy of Latin', tema_ru = 'Римская цивилизация: наследие латинского языка'
WHERE curso = '2º Bachillerato' AND asignatura = 'Latín' AND tema = 'Civilización romana: pervivencia del latín';

UPDATE public.curriculo_temas SET tema_en = 'Advanced Greek morphology and syntax', tema_ru = 'Продвинутая морфология и синтаксис греческого языка'
WHERE curso = '2º Bachillerato' AND asignatura = 'Griego' AND tema = 'Morfología y sintaxis griegas avanzadas';

UPDATE public.curriculo_temas SET tema_en = 'Translation of classical texts', tema_ru = 'Перевод классических текстов'
WHERE curso = '2º Bachillerato' AND asignatura = 'Griego' AND tema = 'Traducción de textos clásicos';

UPDATE public.curriculo_temas SET tema_en = 'Greek literature: main genres and authors', tema_ru = 'Греческая литература: основные жанры и авторы'
WHERE curso = '2º Bachillerato' AND asignatura = 'Griego' AND tema = 'Literatura griega: géneros y autores principales';

UPDATE public.curriculo_temas SET tema_en = 'The legacy of ancient Greece', tema_ru = 'Наследие древнегреческой культуры'
WHERE curso = '2º Bachillerato' AND asignatura = 'Griego' AND tema = 'Pervivencia del legado griego';

UPDATE public.curriculo_temas SET tema_en = 'Advanced life drawing', tema_ru = 'Продвинутое рисование с натуры'
WHERE curso = '2º Bachillerato' AND asignatura = 'Dibujo Artístico' AND tema = 'Dibujo del natural avanzado';

UPDATE public.curriculo_temas SET tema_en = 'The human figure in motion', tema_ru = 'Человеческая фигура в движении'
WHERE curso = '2º Bachillerato' AND asignatura = 'Dibujo Artístico' AND tema = 'La figura humana en movimiento';

UPDATE public.curriculo_temas SET tema_en = 'Mixed media and experimentation', tema_ru = 'Смешанные техники и эксперимент'
WHERE curso = '2º Bachillerato' AND asignatura = 'Dibujo Artístico' AND tema = 'Técnicas mixtas y experimentación';

UPDATE public.curriculo_temas SET tema_en = 'Final art project', tema_ru = 'Итоговый художественный проект'
WHERE curso = '2º Bachillerato' AND asignatura = 'Dibujo Artístico' AND tema = 'Proyecto artístico final';

UPDATE public.curriculo_temas SET tema_en = 'Advanced analysis of audiovisual products', tema_ru = 'Продвинутый анализ аудиовизуальных произведений'
WHERE curso = '2º Bachillerato' AND asignatura = 'Cultura Audiovisual' AND tema = 'Análisis avanzado de productos audiovisuales';

UPDATE public.curriculo_temas SET tema_en = 'Cinema as art and as industry', tema_ru = 'Кино как искусство и как индустрия'
WHERE curso = '2º Bachillerato' AND asignatura = 'Cultura Audiovisual' AND tema = 'El cine como arte y como industria';

UPDATE public.curriculo_temas SET tema_en = 'Audiovisual production: short film or documentary', tema_ru = 'Аудиовизуальное производство: короткометражный или документальный фильм'
WHERE curso = '2º Bachillerato' AND asignatura = 'Cultura Audiovisual' AND tema = 'Producción audiovisual: cortometraje o documental';

UPDATE public.curriculo_temas SET tema_en = 'New media and digital culture', tema_ru = 'Новые медиа и цифровая культура'
WHERE curso = '2º Bachillerato' AND asignatura = 'Cultura Audiovisual' AND tema = 'Los nuevos medios y la cultura digital';

UPDATE public.curriculo_temas SET tema_en = 'The concept and history of design', tema_ru = 'Понятие и история дизайна'
WHERE curso = '2º Bachillerato' AND asignatura = 'Diseño' AND tema = 'Concepto e historia del diseño';

UPDATE public.curriculo_temas SET tema_en = 'Visual syntax, form and colour', tema_ru = 'Визуальный синтаксис, форма и цвет'
WHERE curso = '2º Bachillerato' AND asignatura = 'Diseño' AND tema = 'Sintaxis visual, forma y color';

UPDATE public.curriculo_temas SET tema_en = 'Design project methodology', tema_ru = 'Методология проектирования'
WHERE curso = '2º Bachillerato' AND asignatura = 'Diseño' AND tema = 'Metodología proyectual';

UPDATE public.curriculo_temas SET tema_en = 'Graphic design', tema_ru = 'Графический дизайн'
WHERE curso = '2º Bachillerato' AND asignatura = 'Diseño' AND tema = 'Diseño gráfico';

UPDATE public.curriculo_temas SET tema_en = 'Product design', tema_ru = 'Дизайн продукта'
WHERE curso = '2º Bachillerato' AND asignatura = 'Diseño' AND tema = 'Diseño de producto';

UPDATE public.curriculo_temas SET tema_en = 'Interior design', tema_ru = 'Дизайн интерьера'
WHERE curso = '2º Bachillerato' AND asignatura = 'Diseño' AND tema = 'Diseño de interiores';


-- ── Comprobación ──────────────────────────────────────────────
-- Si esto devuelve filas, algún tema se quedó sin traducir.
-- SELECT curso, asignatura, tema FROM public.curriculo_temas WHERE tema_en IS NULL OR tema_ru IS NULL;
