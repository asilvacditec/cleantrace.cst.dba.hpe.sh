#!/bin/bash
#
# HPE: CRITICAL SERVICES TEAM
#
# File: cleantrace.cst.dba.hpe.sh
# Author: Aparecido Souza da Silva
# Date: 13/03/2017
#
# Sintaxe: <PATH>/cleantrace.cst.dba.hpe.sh
#   EJEMPLOS:
#      manualmente: /home/oracle/hpdba/bin/cleantrace.cst.dba.hpe.sh
#          crontab: 0 */1 * * * /home/oracle/hpdba/bin/cleantrace.cst.dba.hpe.sh > /home/oracle/hpdba/bin/cleantrace.cst.dba.hpe.sh.log 2>&1
#
#
# Importante: Para que el script funcione correctamente se debe configurar
#             las variables DIRECTORIES_TO_SEARCH, FILES_TO_SEARCH, RETENCION, SHORTP, LONGP
#             * DIRECTORIES_TO_SEARCH debe recibir los directorios a seren limpios (-trace)
#               Por defecto DIRECTORIES_TO_SEARCH esta configurado como $ORACLE_BASE/admin (10g y abajo) y $ORACLE_BASE/diag (11g y arriba)
#               Siguiendo el standard /oracle como $ORACLE_BASE
#             * FILES_TO_SEARCH debe recibir las extenciones de los archivos a seren limpios (-trace)
#             * RETENCION debe recibir la cantidad de dias de la retencion (-trace)
#             * SHORTP debe recibir la cantidade de horas para el parametro SHORTP_POLICY (-adr)
#             * LONGP debe recibir la cantidade de horas para el parametro LONGP_POLICY (-adr)
#
#
#
#
# Rutina para limpiar areas de trace de ORACLE
# Instrucciones de la configuracion en el script
# Se puede configurar los directorios a recorrer, los tipos de archivos y la RETENCION
# Sintaxe: <PATH>/cleantrace.cst.dba.hpe.sh <parametro>"
# El comando debe ser ejecutado con solamente un de los parametros abajo:
#   -trace : limpia los archivos con las extensiones y directorios configurados en el script
#   -adr   : limpia los archivos via ADRCI (11g y superior)
#   -all   : ejecuta ambas las tareas de -trace y -adr
#   -list  : *** Solamente exibe *** los archivos con las extensiones y directorios configurados en el script
#   -help  : exibe esta ayuda
#
# CHANGE LOG:
# 14/03/2017 - Verificacion si el archivo esta en uso en la funccion cleantrace
#            - Inclusion de la rutina para limpiar ADR
# 15/03/2017 - Creacion de log
# 16/03/2017 - Cambio de la variable HPADMINBIN para hpdba
#            - Cambio de la ruta de los logs para $hpdba/log
#            - Saque de la variable ORACLE_BASE por no ocuparla
#            - Inclusion de rutina para revisar si la carpeta $hpdba/log existe, sino la crea
#            - Inclusion de rutina para revisar si el proceso ya esta en ejecucion
# 17/03/2017 - Modificado la revision del proceso para que se pueda ejecutar con dos usuarios distintos
#            - Agregado al log de ejecucion el parametro pasado
#            - Las variables SHORTP y LONGP reciben el valor automaticamente segun el valor pasado a $RETENCION
#            - Agregado seguridad para que no se ejecute como usuario root
# 20/03/2017 - Agregado chequeo si el comando ADRCI existe
#


# VARIABLES MODIFICABLES

# Variables ORACLE_HOME para 11g por delante (Necesario para ejecucion del ADRCI)
export ORACLE_HOME=
# Directorio de trabajo de HP, donde estan los logs y scripts
export hpdba=
# Directorios donde se busca los archivos (*** separados por un espacio vacio ***)
export DIRECTORIES_TO_SEARCH="/oracle/admin/ /oracle/diag/ $hpdba/log/"
# Archivos a seren borrados (*** separados por un espacio ***)
export FILES_TO_SEARCH="*trc *trm *aud"
# RETENCION para borrar los mas antiguos que $RETENCION (funccion cleantrace)
export RETENCION=3



# VARIABLES DEL SISTEMA
export IDENTIFICADOR=`date +%Y%m%d%H%M%S`
export LOGFILE=$hpdba/log/cleantrace_${IDENTIFICADOR}.aud
export ADRSCRIPT=/tmp/adr_dinamic_script_${IDENTIFICADOR}.adr
export LSOF=/usr/sbin/lsof
export AWK=/usr/bin/awk
export PATH=$ORACLE_HOME/bin:$PATH
export ADRCI=$ORACLE_HOME/bin/adrci
export SHORTP=`echo $(($RETENCION * 24))`
export LONGP=`echo $(($RETENCION * 24))`

# Si el usuario que ejecutar el script fuera root sali sin hacer nada
if [ "$(id -u)" == "0" ]; then
  echo "El script no se debe ejecutar como root!"
  echo "Favor ejecutar el script con el usuario owner del Oracle Database o del Oracle Grid Infraestructure."
  exit 1
fi

# Revisa si el proceso encontrase en ejecucion
export PROCESS=`ps -efww | grep $USER | grep -w "cleantrace.cst.dba.hpe.sh" | grep -v grep | grep -v $$ | wc -l`
if [ ${PROCESS} -gt 0 ]; then
  echo "El proceso ya esta en ejecucion"
  ps -efww | grep -w "cleantrace.cst.dba.hpe.sh" | grep -v grep | grep -v $$
  exit 1;
fi

# Crea el directorio log caso no exista
if [ ! -d $hpdba/log ]; then
  mkdir $hpdba/log
fi

# Rutina para limpieza del los traces de acuerdo a los directorios y archivos en (DIRECTORIES_TO_SEARCH y FILES_TO_SEARCH)
function cleantrace () {
  echo "INICIO PROCESO cleantrace" `date '+%d/%m/%y %T'`
  TEMPFILE="/tmp/cleantrace_lsof_${IDENTIFICADOR}.txt"
  $LSOF | $AWK '{print $9}' > $TEMPFILE
  for z in $1; do
    for y in $2; do
      for x in `find $z -name $y`; do
        ARCHIVO=`find "$x" -mtime +$3 -exec ls {} \;`
        if [ ! -z "$ARCHIVO" ]; then
          grep "$ARCHIVO" $TEMPFILE 1>/dev/null
          if [ $? -eq 1 ]; then
            if [ "$4" == "list" ]; then
              ls -lh $ARCHIVO
            else
              ls -lh $ARCHIVO
              rm -f $ARCHIVO
            fi
          else
            echo `ls -lh $ARCHIVO` "   *** ESTA EN USO! ***"
          fi
        fi
      done
    done
  done
  rm -f $TEMPFILE
  echo "FIN PROCESO cleantrace" `date '+%d/%m/%y %T'`
}

# Rutina para limpieza del ADR files
function adrclean() {
  echo "INICIO PROCESO adrclean" `date '+%d/%m/%y %T'`
  if [ ! -x $ADRCI ];then
    echo "Comando $ADRCI no encontrado, favor revisar la version si es 11g o arriba"
	echo "O si la variable ORACLE_HOME esta configurada correctamente..."
	exit 1
  fi
  $ADRCI exec="select SHORTP_POLICY,LONGP_POLICY from ADR_CONTROL;"
  for x in `$ADRCI exec="show homes" | grep -v "ADR Homes" | grep -v clients`
  do
    echo "set home $x;" >> $ADRSCRIPT
    echo "set control (SHORTP_POLICY=$SHORTP);" >> $ADRSCRIPT
    echo "set control (LONGP_POLICY=$LONGP);" >> $ADRSCRIPT
    echo "purge;" >> $ADRSCRIPT
  done
  $ADRCI script=$ADRSCRIPT
  $ADRCI exec="select SHORTP_POLICY,LONGP_POLICY from ADR_CONTROL;"
  rm -f $ADRSCRIPT
  echo "FIN PROCESO adrclean" `date '+%d/%m/%y %T'`
}

# Pone al log el parametro pasado, los directorios y archivos configurados
function cabecera(){
if [ ! -z "$1" ]; then
  echo "$1" | tee -a $LOGFILE
  echo "Directorios     : $DIRECTORIES_TO_SEARCH" | tee -a $LOGFILE
  echo "Archivos        : $FILES_TO_SEARCH" | tee -a $LOGFILE
fi
}


# Rutina principal - se ejecuta de acuerdo con el parametro pasado al script
case "$1" in
  "-adr")
    cabecera $1
    adrclean | tee -a $LOGFILE
    ;;
  "-trace")
    cabecera $1
    cleantrace "$DIRECTORIES_TO_SEARCH" "$FILES_TO_SEARCH" "$RETENCION" | tee -a $LOGFILE
    ;;
  "-all")
    cabecera $1
    adrclean | tee -a $LOGFILE
    cleantrace "$DIRECTORIES_TO_SEARCH" "$FILES_TO_SEARCH" "$RETENCION" | tee -a $LOGFILE
    ;;
  "-list")
    cabecera $1
    cleantrace "$DIRECTORIES_TO_SEARCH" "$FILES_TO_SEARCH" "$RETENCION" "list" | tee -a $LOGFILE
    ;;
  "-help")
    echo
    echo
    echo
    echo "Rutina para limpiar areas de trace de ORACLE"
    echo "Instrucciones de la configuracion en el script"
    echo "Se puede configurar los directorios a recorrer, los tipos de archivos y la RETENCION"
    echo "Sintaxe: <PATH>/cleantrace.cst.dba.hpe.sh <parametro>"
    echo "El comando debe ser ejecutado con solamente un de los parametros abajo:"
    echo "-trace : limpia los archivos con las extensiones y directorios configurados en el script"
    echo "-adr   : limpia los archivos via ADRCI (11g y superior)"
    echo "-all   : ejecuta ambas las tareas de -trace y -adr"
    echo "-list  : *** Solamente exibe *** los archivos con las extensiones y directorios configurados en el script"
    echo "-help  : exibe esta ayuda"
    echo
    echo
    echo
    ;;
  *)
    echo
    echo "Favor informa un de los parametros: [ -trace | -adr | -all | -list | -help ]"
    echo "Ejemplo: <PATH>/cleantrace.cst.dba.hpe.sh -list"
    echo
    ;;
esac
