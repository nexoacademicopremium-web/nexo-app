// ============================================================
// NEXO ACADÉMICO — Banco del test de nivel de inglés
//
// Las preguntas del test de nivel no se escriben: son siempre estas.
// Cuando el admin crea un test de nivelación de inglés, se cargan de
// aquí enteras, con sus partes y su puntuación.
//
// 109 preguntas · 117 puntos
//   Parte 1 · Grammar & Vocabulary       60 preg × 1 pt = 60
//   Parte 2 · Open Cloze                 16 huecos × 1  = 16
//   Parte 3 · Word Formation             10 preg × 1    = 10
//   Parte 4 · Key Word Transformation     8 preg × 2    = 16
//   Parte 5 · Vocabulary in Use          15 preg × 1    = 15
//
// ⚠️ LAS RESPUESTAS LAS HE RESUELTO YO. Están sin validar por un
//    profesor. Antes de pasarle esto a un alumno hay que repasarlas:
//    una respuesta mal puesta le da un nivel equivocado y nadie se
//    entera. Las que admiten discusión llevan un comentario `revisar`.
//
// Formatos de respuesta:
//   tipo 'opcion'  → r es 'a'|'b'|'c'|'d'
//   tipo 'escribe' → r es un array con todas las formas que se dan por
//                    buenas (se compara sin mayúsculas ni espacios de
//                    más), porque en un hueco caben varias palabras
//                    igual de correctas.
// ============================================================

const TEST_NIVEL_INGLES = {
  titulo:     'Test de nivel · Inglés',
  asignatura: 'Inglés',

  partes: [
    {
      nombre: 'Grammar & Vocabulary',
      tipo:   'opcion',
      puntos: 1,
      instrucciones: 'Elige la opción correcta (A, B, C o D).',
      preguntas: [
        { e: 'I ___ this film before. Let\'s watch something else.', o: ['saw', 'have seen', 'was seeing', 'see'], r: 'b' },
        { e: 'She ___ TV when the phone rang.', o: ['watched', 'watches', 'was watching', 'has watched'], r: 'c' },
        { e: 'This exercise is ___ than the last one.', o: ['more difficult', 'difficulter', 'most difficult', 'as difficult'], r: 'a' },
        { e: 'If it ___ tomorrow, we\'ll cancel the picnic.', o: ['rains', 'will rain', 'rained', 'is raining'], r: 'a' },
        { e: 'You ___ smoke in here — it\'s forbidden.', o: ['don\'t have to', 'mustn\'t', 'shouldn\'t to', 'don\'t must'], r: 'b' },
        { e: 'Look at those clouds! It ___ rain.', o: ['will', 'is going to', 'is', 'would'], r: 'b' },
        { e: 'The woman ___ lives next door is a doctor.', o: ['which', 'whose', 'who', 'whom'], r: 'c' },
        { e: 'This cheese ___ in France.', o: ['makes', 'is made', 'is making', 'made'], r: 'b' },
        { e: 'There isn\'t ___ milk left in the fridge.', o: ['many', 'much', 'a few', 'several'], r: 'b' },
        { e: 'I enjoy ___ to music while I work.', o: ['listen', 'to listen', 'listening', 'listened'], r: 'c' },
        { e: 'Can you ___ my cat while I\'m on holiday?', o: ['look after', 'look for', 'look at', 'look up'], r: 'a' },
        { e: 'I need to ___ my homework before dinner.', o: ['make', 'do', 'have', 'take'], r: 'b' },
        { e: 'He\'s very good ___ maths.', o: ['in', 'at', 'for', 'with'], r: 'b' },
        { e: 'The hotel room was extremely small. In other words, it was ___.', o: ['spacious', 'tiny', 'comfortable', 'modern'], r: 'b' },
        { e: 'I usually ___ breakfast at 7 am.', o: ['do', 'make', 'have', 'take'], r: 'c' },
        { e: 'If I ___ you were coming, I would have cooked more food.', o: ['knew', 'had known', 'would know', 'know'], r: 'b' },
        { e: 'She said that she ___ tired.', o: ['is', 'was', 'has been', 'be'], r: 'b' },
        { e: 'He asked me ___.', o: ['where did I live', 'where I lived', 'where I live', 'where lived I'], r: 'b' },
        { e: 'The report ___ by tomorrow morning.', o: ['must finish', 'must be finished', 'must be finishing', 'must have finished'], r: 'b' },
        { e: 'My brother, ___ has just moved to Canada, works as an engineer.', o: ['that', 'who', 'which', 'whom'], r: 'b' },
        { e: 'I ___ play the piano when I was a child, but I\'ve forgotten how now.', o: ['use to', 'was used to', 'used to', 'would used to'], r: 'c' },
        { e: 'She isn\'t answering her phone. She ___ have already left.', o: ['must', 'should', 'can', 'would'], r: 'a' },
        { e: '___ the heavy rain, the match continued.', o: ['Although', 'Despite', 'However', 'Even though'], r: 'b' },
        { e: 'I was really ___ by the ending of the film.', o: ['impress', 'impressive', 'impressed', 'impression'], r: 'c' },
        { e: 'Don\'t forget to ___ the lights when you leave.', o: ['turn off', 'turn into', 'turn up', 'turn out'], r: 'a', revisar: '"turn out the lights" también es correcto en inglés británico' },
        { e: 'Can you give me some ___ on how to improve my CV?', o: ['advices', 'advice', 'suggestion', 'suggest'], r: 'b' },
        { e: 'It\'s important to ___ a good relationship with your colleagues.', o: ['do', 'make', 'maintain', 'held'], r: 'c' },
        { e: 'Many companies are trying to reduce their carbon ___.', o: ['footprint', 'footstep', 'fingerprint', 'trace'], r: 'a' },
        { e: 'I\'m not a morning person — it takes me ages to ___.', o: ['wake up', 'wake on', 'get on', 'wake off'], r: 'a' },
        { e: 'He\'s very ambitious and always likes to ___ risks in business.', o: ['take', 'do', 'make', 'have'], r: 'a' },
        { e: '___ had I arrived home than the phone started ringing.', o: ['No sooner', 'Hardly', 'Scarcely', 'Barely'], r: 'a' },
        { e: '___ really annoys me is people who talk during films.', o: ['What', 'That', 'It', 'This'], r: 'a' },
        { e: 'I wish I ___ harder for the exam — I would have passed easily.', o: ['studied', 'had studied', 'would study', 'study'], r: 'b' },
        { e: 'The doctor recommended that he ___ more exercise.', o: ['does', 'do', 'did', 'will do'], r: 'b' },
        { e: 'We ___ our house painted last month.', o: ['had', 'did', 'made', 'took'], r: 'a' },
        { e: '___ nothing more to say, she left the room.', o: ['Having', 'Had', 'Have', 'To have'], r: 'a' },
        { e: 'The man ___ over there is my uncle.', o: ['who standing', 'stands', 'standing', 'stood'], r: 'c' },
        { e: 'You ___ bought so much food — half of it will go to waste.', o: ['didn\'t need to', 'needn\'t have', 'mustn\'t have', 'shouldn\'t'], r: 'b' },
        { e: 'You can borrow my car ___ you bring it back before 6 pm.', o: ['provided that', 'even though', 'in case', 'despite'], r: 'a' },
        { e: 'A: I don\'t think it\'ll rain. B: I hope ___.', o: ['so', 'that', 'it', 'yes'], r: 'a' },
        { e: 'The government has come under ___ fire for its handling of the crisis.', o: ['heavy', 'strong', 'hard', 'big'], r: 'a' },
        { e: 'Her ___ to detail makes her an excellent editor.', o: ['attentive', 'attention', 'attentively', 'attend'], r: 'b' },
        { e: 'The peace talks suddenly ___ when the delegation walked out of the room.', o: ['broke down', 'broke up', 'broke out', 'broke off'], r: 'a', revisar: '"broke off" (se interrumpieron) también encaja con "walked out"' },
        { e: 'The CEO\'s speech was full of ___ remarks that many found condescending.', o: ['patronizing', 'patronal', 'patronized', 'patron'], r: 'a' },
        { e: 'After months of hard work, the project finally ___.', o: ['paid off', 'paid up', 'paid out', 'paid back'], r: 'a' },
        { e: '___ was the flight delayed, but our luggage was also lost.', o: ['Not only', 'Not never', 'No only', 'Not just'], r: 'a' },
        { e: '___ hard she tried, she couldn\'t open the jar.', o: ['How', 'However', 'As', 'So'], r: 'b' },
        { e: 'It is essential that the matter ___ investigated immediately.', o: ['is', 'be', 'was', 'will be'], r: 'b' },
        { e: '___ the CEO to resign, the company\'s shares would probably fall.', o: ['If', 'Were', 'Should', 'Was'], r: 'b' },
        { e: 'They have introduced a new scheme ___ employees can buy shares in the company.', o: ['whereby', 'wherein', 'whereupon', 'whereas'], r: 'a' },
        { e: 'My grandmother has always been very ___ — she never wastes anything.', o: ['economic', 'economical', 'economics', 'economy'], r: 'b' },
        { e: 'I think you\'re barking up the wrong ___ if you think he\'s responsible for this.', o: ['tree', 'path', 'road', 'branch'], r: 'a' },
        { e: 'The negotiations were fraught ___ difficulty from the very beginning.', o: ['of', 'by', 'with', 'in'], r: 'c' },
        { e: 'There was a general feeling of ___ among staff after the announcement.', o: ['disgruntlement', 'disgruntled', 'disgruntle', 'disgruntling'], r: 'a' },
        { e: 'The committee decided to ___ the proposal for further review.', o: ['shelve', 'shelf', 'unshelve', 'shell'], r: 'a' },
        { e: 'She has a good eye for detail, which makes her ___ suited to quality control.', o: ['ideal', 'ideally', 'idea', 'idealize'], r: 'b' },
        { e: 'The minister was accused of trying to ___ public opinion through selective use of statistics.', o: ['manipulate', 'fabricate', 'generate', 'stimulate'], r: 'a' },
        { e: 'The two countries were on the ___ of war after the border incident.', o: ['verge', 'edge', 'border', 'brink'], r: 'd', revisar: '"on the verge of war" (opción A) es igual de correcto' },
        { e: 'The report\'s findings were largely ___ by subsequent research.', o: ['backed up', 'corroborated', 'proved', 'shown'], r: 'b' },
        { e: 'Let\'s not beat around the ___ — sales figures are simply not good enough.', o: ['tree', 'bush', 'field', 'corner'], r: 'b' },
      ],
    },

    {
      nombre: 'Open Cloze',
      tipo:   'escribe',
      puntos: 1,
      instrucciones: 'Completa cada hueco con UNA sola palabra.',
      // Dos textos de ocho huecos cada uno. El texto entero acompaña a
      // cada hueco, para que el alumno lea en contexto sin subir y bajar.
      textos: [
        {
          titulo: 'Texto 1',
          cuerpo: 'Last summer, my sister and I decided to travel around Portugal for two weeks. '
                + 'We had never been (1)___ the country before, so we were really excited. On (2)___ first day, '
                + 'we visited Lisbon and walked (3)___ the old streets for hours. The weather was so hot (4)___ '
                + 'we had to stop every few minutes to drink water. (5)___ of the restaurants we tried were '
                + 'absolutely delicious, especially the fish dishes. By the end of the trip, we (6)___ visited '
                + 'five different cities. We only had ten days, so we (7)___ to skip the south of the country. '
                + "We're already planning (8)___ go back next year.",
        },
        {
          titulo: 'Texto 2',
          cuerpo: 'Remote work has transformed the way many of us live and work. (1)___ has this shift been more '
                + 'visible than in large cities, where office towers now stand half-empty. Some economists argue '
                + 'that, (2)___ the initial disruption, remote work has ultimately made the workforce more '
                + 'productive. Others, (3)___, believe that it has eroded the sense of community that '
                + 'traditionally existed within companies. (4)___ matter which side of the debate you fall on, '
                + 'it is clear that the traditional nine-to-five office model is unlikely to return in (5)___ '
                + 'original form. Employees have grown accustomed to the flexibility remote work provides, and '
                + 'few would be willing to give it (6)___ without a fight. (7)___ this trend continues, cities '
                + 'may need to rethink (8)___ they use office space altogether.',
        },
      ],
      preguntas: [
        { texto: 0, hueco: 1, r: ['to'] },
        { texto: 0, hueco: 2, r: ['our', 'the'] },
        { texto: 0, hueco: 3, r: ['around', 'through', 'along', 'down'] },
        { texto: 0, hueco: 4, r: ['that'] },
        { texto: 0, hueco: 5, r: ['all', 'most', 'some', 'many'] },
        { texto: 0, hueco: 6, r: ['had'] },
        { texto: 0, hueco: 7, r: ['had'] },
        { texto: 0, hueco: 8, r: ['to'] },
        { texto: 1, hueco: 1, r: ['nowhere'] },
        { texto: 1, hueco: 2, r: ['despite', 'notwithstanding'] },
        { texto: 1, hueco: 3, r: ['however'] },
        { texto: 1, hueco: 4, r: ['no'] },
        { texto: 1, hueco: 5, r: ['its'] },
        { texto: 1, hueco: 6, r: ['up'] },
        { texto: 1, hueco: 7, r: ['if', 'should'] },
        { texto: 1, hueco: 8, r: ['how'] },
      ],
    },

    {
      nombre: 'Word Formation',
      tipo:   'escribe',
      puntos: 1,
      instrucciones: 'Usa la palabra en mayúsculas para formar la que encaja en el hueco.',
      preguntas: [
        { e: 'Her presentation was extremely ___.', clave: 'IMPRESS', r: ['impressive'] },
        { e: "The company's new policy has led to widespread ___ among employees, many of whom have complained to HR.", clave: 'SATISFY', r: ['dissatisfaction'] },
        { e: "It's important to remain ___ during a job interview.", clave: 'CONFIDENCE', r: ['confident'] },
        { e: "The novel's ___ ending surprised every reader.", clave: 'EXPECT', r: ['unexpected'] },
        { e: 'Scientists are still trying to find a ___ explanation for the phenomenon.', clave: 'SCIENCE', r: ['scientific'] },
        { e: 'The company was praised for its ___ approach to recycling.', clave: 'INNOVATE', r: ['innovative'] },
        { e: "The manager's decision was met with strong ___ from the staff.", clave: 'OPPOSE', r: ['opposition'] },
        { e: 'She gave a very ___ account of what had happened.', clave: 'DETAIL', r: ['detailed'] },
        { e: 'The new regulations will ___ affect how small businesses operate.', clave: 'SIGNIFICANT', r: ['significantly'] },
        { e: 'His argument was based on a fundamental ___ of the data.', clave: 'UNDERSTAND', r: ['misunderstanding'] },
      ],
    },

    {
      nombre: 'Key Word Transformation',
      tipo:   'escribe',
      puntos: 2,
      instrucciones: 'Reescribe la frase usando la palabra clave, sin cambiar su significado.',
      // Se escribe solo lo que va en el hueco. Se aceptan las formas
      // contraídas y las de dos palabras por igual.
      preguntas: [
        { e: "It's not necessary for you to finish the report today.", clave: 'HAVE',
          inicio: 'You', fin: 'the report today.',
          r: ["don't have to finish", 'do not have to finish'] },
        { e: 'I last saw her three years ago.', clave: 'SEEN',
          inicio: 'I', fin: 'three years.',
          r: ["haven't seen her for", 'have not seen her for'] },
        { e: 'Someone stole my bike while I was at work.', clave: 'HAD',
          inicio: 'My bike', fin: 'I was at work.',
          r: ['had been stolen while', 'was stolen while'] },
        { e: 'She started learning English five years ago and still learns it now.', clave: 'FOR',
          inicio: 'She', fin: 'five years.',
          r: ['has been learning english for', 'has learnt english for', 'has learned english for'] },
        { e: "I'm sure he didn't know about the meeting.", clave: 'HAVE',
          inicio: 'He', fin: 'about the meeting.',
          r: ["can't have known", 'cannot have known', "couldn't have known"] },
        { e: "It's possible that they missed the train.", clave: 'MIGHT',
          inicio: 'They', fin: 'the train.',
          r: ['might have missed'] },
        { e: 'Despite being very tired, she finished the marathon.', clave: 'THOUGH',
          inicio: '', fin: ', she finished the marathon.',
          r: ['even though she was very tired', 'though she was very tired'] },
        { e: 'I regret not studying harder at university.', clave: 'WISH',
          inicio: 'I', fin: 'harder at university.',
          r: ['wish i had studied'] },
      ],
    },

    {
      nombre: 'Vocabulary in Use',
      tipo:   'opcion',
      puntos: 1,
      instrucciones: 'Colocaciones, phrasal verbs e idioms. Elige la opción correcta.',
      preguntas: [
        { e: 'You should always ___ care when crossing a busy road.', o: ['do', 'take', 'make', 'have'], r: 'b' },
        { e: "It's easy to ___ mistakes when you're tired.", o: ['do', 'make', 'have', 'take'], r: 'b' },
        { e: 'He decided to ___ a stand against the new policy.', o: ['take', 'make', 'do', 'have'], r: 'a' },
        { e: 'Could you ___ me a favour and pick up some milk?', o: ['make', 'do', 'take', 'give'], r: 'b' },
        { e: 'The new evidence ___ doubt on his account of events.', o: ['makes', 'puts', 'casts', 'gives'], r: 'c' },
        { e: 'She had to put up with a lot of criticism early in her career. "Put up with" most nearly means:', o: ['avoid', 'tolerate', 'enjoy', 'cause'], r: 'b' },
        { e: 'The meeting was called off at the last minute. "Called off" most nearly means:', o: ['postponed', 'cancelled', 'started', 'shortened'], r: 'b' },
        { e: 'He came across an old photograph while cleaning the attic. "Came across" most nearly means:', o: ['destroyed', 'looked for', 'found by chance', 'remembered'], r: 'c' },
        { e: 'Prices have gone up considerably over the past year. "Gone up" most nearly means:', o: ['increased', 'decreased', 'stabilised', 'disappeared'], r: 'a' },
        { e: 'They finally managed to sort out the misunderstanding. "Sort out" most nearly means:', o: ['create', 'resolve', 'ignore', 'discuss'], r: 'b' },
        { e: '"It\'s raining cats and dogs outside." This means:', o: ["It's raining very lightly", "It's raining very heavily", "It's about to rain", 'Animals are falling from the sky'], r: 'b' },
        { e: '"I think we should let sleeping dogs lie." This means:', o: ['We should wake everyone up', 'We should not disturb a situation that could cause problems if brought up', 'We should get more sleep', 'We should be more honest'], r: 'b' },
        { e: '"She\'s clearly under the weather today." This means:', o: ["She's outside in the rain", "She's feeling slightly ill", "She's in a bad mood", "She's very busy"], r: 'b' },
        { e: '"That decision really cost him an arm and a leg." This means:', o: ['It caused him a physical injury', 'It was very expensive', 'It took a long time', 'It made him famous'], r: 'b' },
        { e: '"Once in a blue moon, we go out for dinner." This means:', o: ['Very often', 'Every month', 'Very rarely', 'Only at night'], r: 'c' },
      ],
    },
  ],
};
