!/bin/sh

# Definimos la conexion a la Base de Datos de Remedy
_db_password=`cat "/datos/scripts/scripts_REMEDY9/.remedy_sql_defaults"`

# Definimos la conexion a la Base de Datos mySQL
_db="Remedy"
_db_user="root"
_db_CIssggTableName="CIs_ssgg"
_folder_tmp="/datos/scripts/tmp/remedy"
# NOTA: Es importante que el nombre del fichero y de la tabla sean iguales. Es requisito de mysqlimport

echo
echo "Uso:"
echo "   CIs_ssgg.sh -> carga las tabla 'CIs_ssgg' de Remedy"
echo "                Se hace un borrando previo de los datos existentes."
echo

# Como tiene pocos registros, siempre se hace una carga completa.
_now=`date +"%s"`  # Guarda la fecha de cuando se hace la carga en formato unix.

echo `date +"%d/%m/%Y %H:%M:%S"`" - Vaciando tablas..."
mysql --defaults-extra-file=/root/.myroot.cnf -u$_db_user --skip-column-names -e "USE Remedy; DELETE from $_db_CIssggTableName; "


###############################################################################################################
#
# Exportamos de Remedy los datos de contratos
#
###############################################################################################################
# unixODBC - isql Usage
# isql <server> [user [pass]] [options]
# Options:
# -b: Suppress prompts for batch processing. See Notes.
# -c: Display column names on first row (use with -d)
# -dx: Delimit columns with character x.
# -x0xHH: Delimit columns with HH, where x is in hex. For example, 0x09 is the tab character.
# -w: Wrap results in an HTML table.
# -llocnname: Set locale to locname.
# -mn: Limit column display width to n characters.
# -q: wrap char fields in dquotes .
# -L: Length of col display (def:300).
# -n: Use new line processing.
# -v: Display verbose explanations for errors and warnings.
# --version: Display version of unixODBC in use.

# Los datos de personas las exportamos en ASCII separando los campos por el código hex 0x01 y los registros por \n
# Además añadimos @ como texto fijo del primer campo (se usa más tarde para delimitar los registros)
# Oscar - añado al comando ISQL '-L500' para que no se corte el texto del campo 'Datos Contrato'

echo `date +"%d/%m/%Y %H:%M:%S"`" - Exportando todas los CIs a CSV..."

echo "SELECT '@',ReconciliationIdentity__c, AssetID__c, Name_CI__c, Company__c, Site__c FROM [ARSystem].[dbo].[ACU_Contratos_CIs] WHERE Name_CI__c LIKE 'G. de%' OR Name_CI__c LIKE 'Gestión%';" | isql  -v SQLServer sa $_db_password -x0x01 -b -L500 -les_ES.UTF-8 > $_folder_tmp/$_db_CIssggTableName.txt


echo `date +"%d/%m/%Y %H:%M:%S"`" - Conviertiendo CIs"
# Sustituimos el carácter \ por \\, ya que en caso contrario se tomaría como una secuencia de escape.
echo "* Escapamos \\"
sed -i '/\\/ s/\\/\\\\/g' $_folder_tmp/$_db_CIssggTableName.txt

# Sustituye el separador hexadecimal que he usado en iSQL (0x01) por la cadena ascii ~!~
# Con iSQL, el separador sólo puede ser un único caracter. Como es frecuente que ese carácter aparezca en algún lado de los datos, no nos sirve. Por eso usamos un código Hex en iSQL y luego lo
# cambiamos por separador "más raro".
echo "* Sustituimos el separador hex 0x01 por una cadena rara (~!~)"
sed -i 's/\x01/~!~/g' $_folder_tmp/$_db_CIssggTableName.txt


# Eliminamos los retornos de carro que pueda haber en los campos
# No obstante, debemos dejar los retornos de carro de final de registro. Identificamos el final de registro porque hemos añadido el caracter @ como un campo adicional.
echo "* Eliminamos los new line (\\n)"
sed -i -r ':a;N;/\n@/!s/\n//;ta;P;D' $_folder_tmp/$_db_CIssggTableName.txt


# Eliminamos el campo inicial inventado usado para marcar el comienzo del registro
echo "* Eliminamos el campo @"
sed -i 's/@~!~//' $_folder_tmp/$_db_CIssggTableName.txt
