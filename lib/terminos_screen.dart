import 'package:flutter/material.dart';

import 'biometria_screen.dart';
import 'theme.dart';

/// Términos y condiciones / consentimiento. Aparece después del inicio y antes
/// de la verificación. Declara qué datos se recogen (base del consentimiento
/// informado del estudio).
class TerminosScreen extends StatefulWidget {
  const TerminosScreen({super.key});
  @override
  State<TerminosScreen> createState() => _TerminosScreenState();
}

class _TerminosScreenState extends State<TerminosScreen> {
  bool _acepta = false;

  void _continuar() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BiometriaScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Wordmark(size: 22),
              const SizedBox(height: 8),
              Text('TÉRMINOS Y CONDICIONES',
                  style: R.mono(size: 12, color: R.verde)),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _p('rastro es una experiencia de archivo de redes sociales '
                          'y un proyecto de investigación de diseño (UDP).'),
                      _h('Qué recogemos'),
                      _p('• Las fotos que tomas cuando la app te avisa.\n'
                          '• El contexto de cada foto: la hora y el lugar.\n'
                          '• Un escaneo facial para crear tu avatar.\n'
                          '• Cuándo abres la app.'),
                      _h('Para qué'),
                      _p('Para construir tu archivo personal durante una semana y '
                          'estudiar cómo las personas se relacionan con sus registros. '
                          'Los datos los trata el equipo de investigación.'),
                      _h('Tu participación'),
                      _p('• Es voluntaria y dura 7 días.\n'
                          '• Puedes dejar de participar cuando quieras.\n'
                          '• Al final te mostraremos tu archivo y conversaremos contigo.'),
                      _h('Privacidad'),
                      _p('Tu identidad queda bajo un alias que tú eliges. No pedimos '
                          'tu correo ni tu número. Puedes pedir que borremos tus datos.'),

                      _h('1. Aceptación de los términos'),
                      _p('Al acceder y utilizar esta aplicación, el usuario reconoce haber '
                          'leído, comprendido y aceptado íntegramente los presentes términos y '
                          'condiciones de uso, así como cualquier política, directriz, anexo o '
                          'documento complementario que se incorpore por referencia, '
                          'comprometiéndose a cumplirlos en su totalidad. En caso de no estar '
                          'de acuerdo con cualquiera de las disposiciones aquí contenidas, el '
                          'usuario deberá abstenerse de utilizar la aplicación.'),

                      _h('2. Licencia de uso'),
                      _p('Se otorga al usuario una licencia limitada, no exclusiva, '
                          'intransferible, revocable y sin posibilidad de sublicenciamiento, '
                          'para acceder y utilizar la aplicación únicamente con fines '
                          'personales y no comerciales, conforme a los límites establecidos en '
                          'el presente documento y en la legislación aplicable vigente.'),

                      _h('3. Conducta del usuario'),
                      _p('El usuario se compromete a utilizar la aplicación de manera diligente, '
                          'lícita y de buena fe, absteniéndose de realizar cualquier acción que '
                          'pueda dañar, inutilizar, sobrecargar, deteriorar o impedir el normal '
                          'funcionamiento de la aplicación, de sus servidores o de los servicios '
                          'asociados, así como de los derechos o intereses de terceros.'),

                      _h('4. Propiedad intelectual'),
                      _p('Todos los contenidos, elementos gráficos, marcas, logotipos, '
                          'nombres comerciales, textos, código fuente, diseños y demás '
                          'materiales son titularidad de sus respectivos propietarios y se '
                          'encuentran protegidos por la normativa nacional e internacional en '
                          'materia de propiedad intelectual e industrial. Queda prohibida su '
                          'reproducción, distribución o transformación sin autorización previa.'),

                      _h('5. Limitación de responsabilidad'),
                      _p('En la máxima medida permitida por la ley, los responsables de la '
                          'aplicación no serán responsables por daños directos, indirectos, '
                          'incidentales, especiales, consecuentes o punitivos, ni por la '
                          'pérdida de datos, beneficios o ingresos derivados del uso o de la '
                          'imposibilidad de uso de la aplicación, con independencia de la '
                          'teoría de responsabilidad invocada.'),

                      _h('6. Indemnización'),
                      _p('El usuario se compromete a mantener indemnes a los responsables de la '
                          'aplicación frente a cualquier reclamación, demanda, sanción, pérdida '
                          'o gasto, incluidos honorarios razonables de asesoría legal, que se '
                          'derive del incumplimiento de los presentes términos o del uso '
                          'indebido de la aplicación por parte del usuario.'),

                      _h('7. Modificaciones'),
                      _p('Los responsables se reservan el derecho de modificar, actualizar o '
                          'sustituir, total o parcialmente y en cualquier momento, los '
                          'presentes términos y condiciones, siendo responsabilidad del usuario '
                          'revisarlos periódicamente. El uso continuado de la aplicación tras '
                          'dichas modificaciones constituirá la aceptación de las mismas.'),

                      _h('8. Cookies y tecnologías similares'),
                      _p('La aplicación podrá emplear identificadores, almacenamiento local y '
                          'tecnologías análogas con el objeto de garantizar su funcionamiento, '
                          'recordar preferencias y recopilar información estadística agregada, '
                          'todo ello conforme a la normativa aplicable y a la presente política.'),

                      _h('9. Servicios de terceros'),
                      _p('La aplicación podrá integrar o enlazar servicios prestados por '
                          'terceros, sobre cuyos contenidos, disponibilidad o prácticas los '
                          'responsables no ejercen control alguno, declinando toda '
                          'responsabilidad respecto de los mismos.'),

                      _h('10. Cesión'),
                      _p('El usuario no podrá ceder ni transferir los derechos u obligaciones '
                          'derivados de los presentes términos sin consentimiento previo y por '
                          'escrito. Los responsables podrán cederlos libremente en el marco de '
                          'reorganizaciones, fusiones o transmisiones de activos.'),

                      _h('11. Divisibilidad'),
                      _p('Si alguna disposición de los presentes términos fuese declarada nula, '
                          'inválida o inaplicable por autoridad competente, dicha disposición se '
                          'interpretará o, en su defecto, se tendrá por no puesta, sin que ello '
                          'afecte la validez y exigibilidad de las restantes disposiciones.'),

                      _h('12. Ley aplicable y jurisdicción'),
                      _p('Los presentes términos se regirán e interpretarán conforme a la '
                          'legislación vigente, sometiéndose las partes, con renuncia expresa a '
                          'cualquier otro fuero que pudiera corresponderles, a los tribunales '
                          'competentes para la resolución de cualquier controversia.'),

                      _h('13. Totalidad del acuerdo'),
                      _p('Los presentes términos, junto con los documentos a los que remiten, '
                          'constituyen el acuerdo íntegro entre el usuario y los responsables en '
                          'relación con el objeto de los mismos, prevaleciendo sobre cualquier '
                          'acuerdo, entendimiento o comunicación previa, verbal o escrita.'),

                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _acepta = !_acepta),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: R.verde, width: 1.5),
                          color: _acepta ? R.verde : Colors.transparent,
                        ),
                        child: _acepta
                            ? const Icon(Icons.check, size: 16, color: R.negro)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('he leído y acepto participar.',
                            style: R.mono(size: 12, color: R.papel)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _acepta ? _continuar : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: R.verde,
                    foregroundColor: R.negro,
                    disabledBackgroundColor: R.oliva,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                  ),
                  child: Text('ACEPTO Y CONTINÚO',
                      style: R.mono(
                          size: 14, color: _acepta ? R.negro : R.gris)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _h(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Text(t.toUpperCase(), style: R.mono(size: 11, color: R.verde)),
      );

  Widget _p(String t) => Text(t,
      style: R.display(size: 14, weight: FontWeight.w400, color: R.papel)
          .copyWith(height: 1.5));
}
