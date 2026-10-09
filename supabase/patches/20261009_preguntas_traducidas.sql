-- ============================================================
-- Traducción de la batería de preguntas (inglés y ruso)
-- Ejecutar en Supabase SQL Editor
--
-- Añade las columnas *_en / *_ru a preguntas_asignatura y traduce
-- las 67 preguntas existentes. El profesor sigue viendo siempre el
-- español salvo que haya elegido otro idioma en el selector; si
-- alguna fila nueva se añade sin traducir, cae automáticamente al
-- español (columnas NULL = usa el original).
-- ============================================================

ALTER TABLE public.preguntas_asignatura
  ADD COLUMN IF NOT EXISTS pregunta_en TEXT,
  ADD COLUMN IF NOT EXISTS pregunta_ru TEXT,
  ADD COLUMN IF NOT EXISTS opciones_en JSONB,
  ADD COLUMN IF NOT EXISTS opciones_ru JSONB;

-- ── Universal ───────────────────────────────────────────────
UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Overall understanding of the topic covered',
  opciones_en = '["Not understood","With difficulty","Good","Fluent"]',
  pregunta_ru = 'Общее понимание пройденной темы',
  opciones_ru = '["Не понял","С трудом","Хорошо","Свободно"]'
WHERE asignatura = 'Universal' AND codigo = 'U1';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Independence solving the activities',
  opciones_en = '["Needed constant help","Occasional help","Solved it alone"]',
  pregunta_ru = 'Самостоятельность при выполнении заданий',
  opciones_ru = '["Нужна была постоянная помощь","Нужна была помощь иногда","Решал сам"]'
WHERE asignatura = 'Universal' AND codigo = 'U2';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Attitude and engagement during the session',
  opciones_en = '["Very engaged","Normal","Distracted","Resistant"]',
  pregunta_ru = 'Настрой и включённость в занятие',
  opciones_ru = '["Очень включён","Обычно","Отвлекался","Сопротивлялся"]'
WHERE asignatura = 'Universal' AND codigo = 'U3';

-- ── Matemáticas ─────────────────────────────────────────────
UPDATE public.preguntas_asignatura SET
  pregunta_en = 'If they get it wrong, where do they get stuck?',
  opciones_en = '["Does not understand the question","Understands the question but does not know which method to apply","Knows what to do but makes mistakes carrying it out","Solves it correctly but gets the final answer wrong","Did not get it wrong"]',
  pregunta_ru = 'Если ошибается, то на каком этапе застревает?',
  opciones_ru = '["Не понимает условие","Понимает условие, но не знает, какой метод применить","Знает, что делать, но ошибается при выполнении","Решает верно, но ошибается в итоговом ответе","Не ошибся"]'
WHERE asignatura = 'Matemáticas' AND codigo = 'M1';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'When they get it wrong, is it a one-off slip or something systematic?',
  opciones_en = '["One-off slip (notices it if pointed out)","Systematic error — does not realise it is wrong","Not applicable (did not get it wrong)"]',
  pregunta_ru = 'Когда ошибается — это случайная оплошность или систематическая ошибка?',
  opciones_ru = '["Случайная оплошность (замечает, если указать)","Систематическая ошибка — не понимает, что неправильно","Не применимо (не ошибся)"]'
WHERE asignatura = 'Matemáticas' AND codigo = 'M2';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Speed of calculation/execution',
  opciones_en = '["Quick","Normal","Slow but correct","Slow and with errors"]',
  pregunta_ru = 'Скорость вычислений/выполнения',
  opciones_ru = '["Быстро","Обычно","Медленно, но верно","Медленно и с ошибками"]'
WHERE asignatura = 'Matemáticas' AND codigo = 'M3';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Applies the method learned to a new exercise (not identical)',
  opciones_en = '["Yes, without trouble","With a hint","No, needs a lot of support"]',
  pregunta_ru = 'Применяет изученный метод к новому заданию (не идентичному)',
  opciones_ru = '["Да, без проблем","С небольшой подсказкой","Нет, нужна большая поддержка"]'
WHERE asignatura = 'Matemáticas' AND codigo = 'M4';

-- ── Física ──────────────────────────────────────────────────
UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Understands the physical phenomenon before applying formulas (can explain it in their own words)',
  opciones_en = '["Yes","Applies formulas without understanding why","Mixed"]',
  pregunta_ru = 'Понимает физическое явление до применения формул (может объяснить своими словами)',
  opciones_ru = '["Да","Применяет формулы, не понимая почему","Смешанно"]'
WHERE asignatura = 'Física' AND codigo = 'F1';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Translates the problem statement into data, quantities and what is being asked',
  opciones_en = '["Independently","With help","No"]',
  pregunta_ru = 'Переводит условие задачи в данные, величины и то, что требуется найти',
  opciones_ru = '["Самостоятельно","С помощью","Нет"]'
WHERE asignatura = 'Física' AND codigo = 'F2';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Carries out the mathematical procedure correctly (including units)',
  opciones_en = '["No errors","Some errors","Frequent errors"]',
  pregunta_ru = 'Правильно выполняет математические расчёты (включая единицы измерения)',
  opciones_ru = '["Без ошибок","Отдельные ошибки","Частые ошибки"]'
WHERE asignatura = 'Física' AND codigo = 'F3';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Checks whether the final result makes sense (units, magnitude, sign)',
  opciones_en = '["Yes, on their own initiative","Only if told to","Never"]',
  pregunta_ru = 'Проверяет, имеет ли смысл итоговый результат (единицы, порядок величины, знак)',
  opciones_ru = '["Да, по собственной инициативе","Только если скажут","Никогда"]'
WHERE asignatura = 'Física' AND codigo = 'F4';

-- ── Química ─────────────────────────────────────────────────
UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Understands what happens at particle level (atoms/molecules/ions), not just the written formula',
  opciones_en = '["Yes, explains it at particle level","Only handles the formula without explaining what happens","Mixed"]',
  pregunta_ru = 'Понимает, что происходит на уровне частиц (атомы/молекулы/ионы), а не только работает с формулой',
  opciones_ru = '["Да, объясняет на уровне частиц","Только работает с формулой, не объясняя суть","Смешанно"]'
WHERE asignatura = 'Química' AND codigo = 'Q1';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Handles formulas/nomenclature correctly',
  opciones_en = '["No errors","Occasional errors","Frequent errors"]',
  pregunta_ru = 'Правильно работает с формулами/номенклатурой',
  opciones_ru = '["Без ошибок","Отдельные ошибки","Частые ошибки"]'
WHERE asignatura = 'Química' AND codigo = 'Q2';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Solves numerical problems (stoichiometry, solutions...) independently',
  opciones_en = '["Yes","With help","No","N/A (no numerical work was done)"]',
  pregunta_ru = 'Самостоятельно решает численные задачи (стехиометрия, растворы...)',
  opciones_ru = '["Да","С помощью","Нет","Н/П (численных задач не было)"]'
WHERE asignatura = 'Química' AND codigo = 'Q3';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Relates the observed/experimental phenomenon to the explanation at particle level',
  opciones_en = '["Yes","With help","No"]',
  pregunta_ru = 'Связывает наблюдаемое/экспериментальное явление с объяснением на уровне частиц',
  opciones_ru = '["Да","С помощью","Нет"]'
WHERE asignatura = 'Química' AND codigo = 'Q4';

-- ── Biología ────────────────────────────────────────────────
UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Understands the biological process/mechanism (not just memorising the name)',
  opciones_en = '["Yes, explains the process in their own words","Only memorises terms without explaining the process","Mixed"]',
  pregunta_ru = 'Понимает биологический процесс/механизм (а не просто запоминает название)',
  opciones_ru = '["Да, объясняет процесс своими словами","Только запоминает термины, не объясняя процесс","Смешанно"]'
WHERE asignatura = 'Biología' AND codigo = 'B1';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Command of the topic''s specific terminology and nomenclature',
  opciones_en = '["No errors","Occasional errors","Frequent errors"]',
  pregunta_ru = 'Владение терминологией и номенклатурой по теме',
  opciones_ru = '["Без ошибок","Отдельные ошибки","Частые ошибки"]'
WHERE asignatura = 'Biología' AND codigo = 'B2';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Relates structure to function (e.g. the shape of a cell/organ to what it does)',
  opciones_en = '["Yes","With help","No"]',
  pregunta_ru = 'Связывает строение и функцию (напр., форму клетки/органа с её работой)',
  opciones_ru = '["Да","С помощью","Нет"]'
WHERE asignatura = 'Biología' AND codigo = 'B3';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Applies the concept to a new case or example',
  opciones_en = '["Yes, independently","With help","No"]',
  pregunta_ru = 'Применяет понятие к новому случаю или примеру',
  opciones_ru = '["Да, самостоятельно","С помощью","Нет"]'
WHERE asignatura = 'Biología' AND codigo = 'B4';

-- ── Historia ────────────────────────────────────────────────
UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Analyses the causes and consequences of events',
  opciones_en = '["Explains cause-and-effect relationships fluently","Identifies causes but struggles to relate them","Only lists events without relating them"]',
  pregunta_ru = 'Анализирует причины и последствия событий',
  opciones_ru = '["Свободно объясняет причинно-следственные связи","Называет причины, но с трудом связывает их","Только перечисляет факты без связи между ними"]'
WHERE asignatura = 'Historia' AND codigo = 'H1';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Places events chronologically and relates them to other periods/events',
  opciones_en = '["Good","Acceptable","Weak"]',
  pregunta_ru = 'Располагает события во времени и связывает с другими периодами/фактами',
  opciones_ru = '["Хорошо","Приемлемо","Слабо"]'
WHERE asignatura = 'Historia' AND codigo = 'H2';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Retains key facts (dates, names, concepts)',
  opciones_en = '["Well","With difficulty","Poorly"]',
  pregunta_ru = 'Запоминает ключевые данные (даты, имена, понятия)',
  opciones_ru = '["Хорошо","С трудом","Плохо"]'
WHERE asignatura = 'Historia' AND codigo = 'H3';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Expression and structure when explaining or writing',
  opciones_en = '["Good","Could improve","Weak"]',
  pregunta_ru = 'Изложение и структура при объяснении или написании',
  opciones_ru = '["Хорошо","Есть что улучшить","Слабо"]'
WHERE asignatura = 'Historia' AND codigo = 'H4';

-- ── Economía ────────────────────────────────────────────────
UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Has a good grasp of the topic''s theoretical concepts and terms',
  opciones_en = '["Good grasp","Knows the basics, with gaps","Does not grasp the concepts"]',
  pregunta_ru = 'Владеет теоретическими понятиями и терминами темы',
  opciones_ru = '["Хорошо владеет","Знает основы, но с пробелами","Не владеет понятиями"]'
WHERE asignatura = 'Economía' AND codigo = 'E1';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Applies the theory to a specific case or figure (not just reciting it)',
  opciones_en = '["Applies it fluently","With help","Only recites it, does not apply it"]',
  pregunta_ru = 'Применяет теорию к конкретному случаю или данным (не просто пересказывает)',
  opciones_ru = '["Применяет свободно","С помощью","Только пересказывает, не применяет"]'
WHERE asignatura = 'Economía' AND codigo = 'E2';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Argues with a chain of reasoning (relates cause and effect between variables)',
  opciones_en = '["Independently","With help","Gives disconnected answers"]',
  pregunta_ru = 'Выстраивает цепочку рассуждений (связывает причину и следствие между переменными)',
  opciones_ru = '["Самостоятельно","С помощью","Даёт отдельные ответы без связи"]'
WHERE asignatura = 'Economía' AND codigo = 'E3';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Solves numerical/graphical exercises',
  opciones_en = '["Independently","With help","No","N/A"]',
  pregunta_ru = 'Решает численные/графические задачи',
  opciones_ru = '["Самостоятельно","С помощью","Нет","Н/П"]'
WHERE asignatura = 'Economía' AND codigo = 'E4';

-- ── Filosofía ───────────────────────────────────────────────
UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Identifies the thesis/main idea of the text or argument',
  opciones_en = '["Yes, precisely","With help","Does not identify it"]',
  pregunta_ru = 'Выявляет тезис/главную идею текста или аргумента',
  opciones_ru = '["Да, точно","С помощью","Не выявляет"]'
WHERE asignatura = 'Filosofía' AND codigo = 'Fi1';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Reconstructs the structure of the argument (premises that support the conclusion)',
  opciones_en = '["Independently","With help","Does not distinguish premises from conclusion"]',
  pregunta_ru = 'Восстанавливает структуру аргумента (предпосылки, подтверждающие вывод)',
  opciones_ru = '["Самостоятельно","С помощью","Не различает предпосылки и вывод"]'
WHERE asignatura = 'Filosofía' AND codigo = 'Fi2';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Understands the philosophical context (author, school, era) and relates it to the text',
  opciones_en = '["Yes","Partially","No"]',
  pregunta_ru = 'Понимает философский контекст (автор, направление, эпоха) и связывает его с текстом',
  opciones_ru = '["Да","Частично","Нет"]'
WHERE asignatura = 'Filosofía' AND codigo = 'Fi3';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Argues and critically evaluates with their own reasoned position (not just repeating)',
  opciones_en = '["Yes, with their own arguments","Repeats ideas without arguing","Cannot do it"]',
  pregunta_ru = 'Аргументирует и критически оценивает, высказывая собственную обоснованную позицию (а не просто повторяет)',
  opciones_ru = '["Да, со своими аргументами","Повторяет идеи без аргументации","Не справляется"]'
WHERE asignatura = 'Filosofía' AND codigo = 'Fi4';

-- ── Geografía ───────────────────────────────────────────────
UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Interprets and uses maps, graphs and geographical data',
  opciones_en = '["Independently","With help","No"]',
  pregunta_ru = 'Читает и использует карты, графики и географические данные',
  opciones_ru = '["Самостоятельно","С помощью","Нет"]'
WHERE asignatura = 'Geografía' AND codigo = 'Gg1';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Relates spatial patterns to their causes (not just locating, but explaining why)',
  opciones_en = '["Explains why","Only describes where it is","No"]',
  pregunta_ru = 'Связывает пространственные закономерности с их причинами (не только находит, но объясняет почему)',
  opciones_ru = '["Объясняет почему","Только описывает местоположение","Нет"]'
WHERE asignatura = 'Geografía' AND codigo = 'Gg2';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Relates physical and human factors (how the environment influences human activity and vice versa)',
  opciones_en = '["Yes","Partially","No"]',
  pregunta_ru = 'Связывает физические и человеческие факторы (как среда влияет на деятельность человека и наоборот)',
  opciones_ru = '["Да","Частично","Нет"]'
WHERE asignatura = 'Geografía' AND codigo = 'Gg3';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Retains and locates key facts (names, figures, locations)',
  opciones_en = '["Well","With difficulty","Poorly"]',
  pregunta_ru = 'Запоминает и находит ключевые данные (названия, цифры, местоположения)',
  opciones_ru = '["Хорошо","С трудом","Плохо"]'
WHERE asignatura = 'Geografía' AND codigo = 'Gg4';

-- ── Lengua Castellana / Valenciano — Gramática (idéntico) ────
UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Level of understanding of the rule/structure',
  opciones_en = '["Correctly identifies the elements","Understands the relationships between them","Applies it independently to new cases"]',
  pregunta_ru = 'Уровень понимания правила/структуры',
  opciones_ru = '["Правильно определяет элементы","Понимает связи между ними","Самостоятельно применяет в новых случаях"]'
WHERE asignatura IN ('Lengua Castellana','Valenciano') AND categoria = 'gramatica' AND codigo = 'G1';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'When they get it wrong, is it because they do not know the rule or because they struggle to apply it?',
  opciones_en = '["Does not know the rule","Knows it but fails to apply it","Did not get it wrong"]',
  pregunta_ru = 'Если ошибается — не знает правило или не может его применить?',
  opciones_ru = '["Не знает правило","Знает, но не может применить","Не ошибся"]'
WHERE asignatura IN ('Lengua Castellana','Valenciano') AND categoria = 'gramatica' AND codigo = 'G2';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Spelling command in the material covered',
  opciones_en = '["Good command","Occasional errors","Frequent errors"]',
  pregunta_ru = 'Владение орфографией в пройденном материале',
  opciones_ru = '["Хорошее владение","Отдельные ошибки","Частые ошибки"]'
WHERE asignatura IN ('Lengua Castellana','Valenciano') AND categoria = 'gramatica' AND codigo = 'G3';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Independence solving application exercises',
  opciones_en = '["Needed constant help","Occasional help","Solved it alone"]',
  pregunta_ru = 'Самостоятельность при выполнении упражнений',
  opciones_ru = '["Нужна была постоянная помощь","Нужна была помощь иногда","Решал сам"]'
WHERE asignatura IN ('Lengua Castellana','Valenciano') AND categoria = 'gramatica' AND codigo = 'G4';

-- ── Lengua Castellana / Valenciano — Comprensión (idéntico) ──
UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Level of reading comprehension reached',
  opciones_en = '["Literal (identifies explicit information)","Inferential (deduces what is not explicit)","Critical (evaluates and argues about the text)"]',
  pregunta_ru = 'Достигнутый уровень понимания текста',
  opciones_ru = '["Буквальный (находит явную информацию)","Логический (делает выводы о неявном)","Критический (оценивает текст и аргументирует)"]'
WHERE asignatura IN ('Lengua Castellana','Valenciano') AND categoria = 'comprension' AND codigo = 'C1';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Written expression: ideas and organisation',
  opciones_en = '["Clear, well-organised ideas","Ideas present but poorly structured","Struggles to express and organise ideas in writing"]',
  pregunta_ru = 'Письменная речь: идеи и организация',
  opciones_ru = '["Ясные и хорошо организованные идеи","Идеи есть, но плохо структурированы","С трудом выражает и организует идеи письменно"]'
WHERE asignatura IN ('Lengua Castellana','Valenciano') AND categoria = 'comprension' AND codigo = 'C2';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Command of grammar/spelling in their own writing',
  opciones_en = '["Good command","Occasional errors","Frequent errors"]',
  pregunta_ru = 'Владение грамматикой/орфографией в собственных текстах',
  opciones_ru = '["Хорошее владение","Отдельные ошибки","Частые ошибки"]'
WHERE asignatura IN ('Lengua Castellana','Valenciano') AND categoria = 'comprension' AND codigo = 'C3';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Literary analysis (if it applies to the text covered)',
  opciones_en = '["Independently","With help","Cannot do it","N/A"]',
  pregunta_ru = 'Литературный анализ (если применимо к пройденному тексту)',
  opciones_ru = '["Самостоятельно","С помощью","Не справляется","Н/П"]'
WHERE asignatura IN ('Lengua Castellana','Valenciano') AND categoria = 'comprension' AND codigo = 'C4';

-- ── Inglés / Francés — Gramática/Vocabulario (idéntico) ──────
UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Level of understanding of the structure/rule covered',
  opciones_en = '["Correctly identifies the elements","Understands the relationships between them","Applies it independently to new cases"]',
  pregunta_ru = 'Уровень понимания изученной структуры/правила',
  opciones_ru = '["Правильно определяет элементы","Понимает связи между ними","Самостоятельно применяет в новых случаях"]'
WHERE asignatura IN ('Inglés','Francés') AND categoria = 'gramatica' AND codigo = 'G1';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'When they get it wrong, is it because they do not know the rule or because they struggle to apply it?',
  opciones_en = '["Does not know the rule","Knows it but fails to apply it","Did not get it wrong"]',
  pregunta_ru = 'Если ошибается — не знает правило или не может его применить?',
  opciones_ru = '["Не знает правило","Знает, но не может применить","Не ошибся"]'
WHERE asignatura IN ('Inglés','Francés') AND categoria = 'gramatica' AND codigo = 'G2';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Command of the topic''s vocabulary',
  opciones_en = '["Good command","Limited vocabulary","Frequently confuses terms"]',
  pregunta_ru = 'Владение словарным запасом по теме',
  opciones_ru = '["Хорошее владение","Ограниченный словарный запас","Часто путает термины"]'
WHERE asignatura IN ('Inglés','Francés') AND categoria = 'gramatica' AND codigo = 'G3';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Independence solving application exercises',
  opciones_en = '["Needed constant help","Occasional help","Solved it alone"]',
  pregunta_ru = 'Самостоятельность при выполнении упражнений',
  opciones_ru = '["Нужна была постоянная помощь","Нужна была помощь иногда","Решал сам"]'
WHERE asignatura IN ('Inglés','Francés') AND categoria = 'gramatica' AND codigo = 'G4';

-- ── Inglés — Comprensión y Expresión escrita ─────────────────
UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Level of reading comprehension reached',
  opciones_en = '["Literal (identifies explicit information)","Inferential (deduces what is not explicit)","Critical (evaluates and argues about the text)"]',
  pregunta_ru = 'Достигнутый уровень понимания текста при чтении (reading)',
  opciones_ru = '["Буквальный (находит явную информацию)","Логический (делает выводы о неявном)","Критический (оценивает текст и аргументирует)"]'
WHERE asignatura = 'Inglés' AND categoria = 'comprension' AND codigo = 'C1';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Written expression: ideas and organisation',
  opciones_en = '["Clear, well-organised ideas","Ideas present but poorly structured","Struggles to express and organise ideas in writing"]',
  pregunta_ru = 'Письменная речь: идеи и организация (writing)',
  opciones_ru = '["Ясные и хорошо организованные идеи","Идеи есть, но плохо структурированы","С трудом выражает и организует идеи письменно"]'
WHERE asignatura = 'Inglés' AND categoria = 'comprension' AND codigo = 'C2';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Command of grammar/spelling in their own writing',
  opciones_en = '["Good command","Occasional errors","Frequent errors"]',
  pregunta_ru = 'Владение грамматикой/орфографией в собственных текстах',
  opciones_ru = '["Хорошее владение","Отдельные ошибки","Частые ошибки"]'
WHERE asignatura = 'Inglés' AND categoria = 'comprension' AND codigo = 'C3';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Translation/interpretation of complex structures (if applicable)',
  opciones_en = '["Independently","With help","Cannot do it","N/A"]',
  pregunta_ru = 'Перевод/интерпретация сложных конструкций (если применимо)',
  opciones_ru = '["Самостоятельно","С помощью","Не справляется","Н/П"]'
WHERE asignatura = 'Inglés' AND categoria = 'comprension' AND codigo = 'C4';

-- ── Francés — Compréhension et expression écrite ─────────────
UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Level of reading comprehension reached',
  opciones_en = '["Literal (identifies explicit information)","Inferential (deduces what is not explicit)","Critical (evaluates and argues about the text)"]',
  pregunta_ru = 'Достигнутый уровень понимания текста при чтении (lecture)',
  opciones_ru = '["Буквальный (находит явную информацию)","Логический (делает выводы о неявном)","Критический (оценивает текст и аргументирует)"]'
WHERE asignatura = 'Francés' AND categoria = 'comprension' AND codigo = 'C1';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Written expression: ideas and organisation',
  opciones_en = '["Clear, well-organised ideas","Ideas present but poorly structured","Struggles to express and organise ideas in writing"]',
  pregunta_ru = 'Письменная речь: идеи и организация (écriture)',
  opciones_ru = '["Ясные и хорошо организованные идеи","Идеи есть, но плохо структурированы","С трудом выражает и организует идеи письменно"]'
WHERE asignatura = 'Francés' AND categoria = 'comprension' AND codigo = 'C2';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Command of grammar/spelling in their own writing',
  opciones_en = '["Good command","Occasional errors","Frequent errors"]',
  pregunta_ru = 'Владение грамматикой/орфографией в собственных текстах',
  opciones_ru = '["Хорошее владение","Отдельные ошибки","Частые ошибки"]'
WHERE asignatura = 'Francés' AND categoria = 'comprension' AND codigo = 'C3';

UPDATE public.preguntas_asignatura SET
  pregunta_en = 'Translation/interpretation of complex structures (if applicable)',
  opciones_en = '["Independently","With help","Cannot do it","N/A"]',
  pregunta_ru = 'Перевод/интерпретация сложных конструкций (если применимо)',
  opciones_ru = '["Самостоятельно","С помощью","Не справляется","Н/П"]'
WHERE asignatura = 'Francés' AND categoria = 'comprension' AND codigo = 'C4';

-- ── Comprobación ──────────────────────────────────────────────
-- Si esto devuelve filas, alguna pregunta se quedó sin traducir.
-- SELECT asignatura, categoria, codigo FROM public.preguntas_asignatura WHERE pregunta_en IS NULL OR pregunta_ru IS NULL;
