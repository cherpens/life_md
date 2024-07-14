#!/bin/bash

## script que se encarga de:
## Acciones en calendar.md: 
##              1. Archiva días pasados.
##              2. Añade fechas
##              3. Implementa eventos en el calendario (presentes en events.md)
##              4. Elimina los eventos que se hayan marcado para tal efecto en events.md. Una vez terminado, los eventos
##                  de events.md que se marcaron para la eliminación en calendar.md, se archivan en la parte inferior del
##                  propio archivo events.md.
## Acciones en todo.md: se encarga de archivar las tareas ya completadas (i.e. las precedidas por una x) del archivo todo.md

index_file="index.md"
calendar_file="calendar.md"
events_file="events.md"
todo_file="todo.md"
past_file="past.md"

# Fecha actual
current_date=$(date +%Y-%m-%d)
# Número de días a añadir al calendario (se puede cambiar, según se necesite)
days_to_add=300

### ------------------ Declaraciones de funciones --------------------------

# Declaro función para añadir eventos en la fecha correspondiente
add_rm_event_to_date() {
    local date=$1
    local event=$2
    local temp_file=$3
    local operation=$4

    linea_fecha=$(grep -n "$date" "$temp_file" | cut -d: -f1)

    if [ ! -z "$linea_fecha" ]; then
        linea_fecha=$((linea_fecha+1))

        # Extrae todas las líneas que comienzan con '+' hasta que encuentre una línea que no lo hace
        eventos_del_dia=$(sed -n "${linea_fecha},/^[^+]/p" "$temp_file" | grep '^+')
                
        case $operation in
            "add")
                # Busca que el evento no se encuentre entre los eventos del día específico
                if ! echo "$eventos_del_dia" | grep -q "$event"; then
                    # Y, de ser así, lo añade
                    sed -i "/$date/a\+ $event" "$temp_file"
                fi
                ;;
            "rm")
                # Busca que el evento se encuentre entre los eventos del día específico
                if echo "$eventos_del_dia" | grep -q "$event"; then
                    # Y, de ser así, busca la línea en la que se encuentra y la elimina
                    linea_evento=$(($(echo "$eventos_del_dia" | grep -n "$event" | cut -d: -f1 | head -n 1) + $linea_fecha - 1))
                    sed -i "${linea_evento} { N; s/^+.*$event.*\n//; }" "$temp_file"   
                fi
                ;;
        esac
    fi
}

# Traductor día semana
translate_weekday() {
    case $1 in
        "lunes") echo "monday" ;;
        "martes") echo "tuesday" ;;
        "miércoles") echo "wednesday" ;;
        "jueves") echo "thursday" ;;
        "viernes") echo "friday" ;;
        "sábado") echo "saturday" ;;
        "domingo") echo "sunday" ;;
    esac
}

# Determina como añadir el evento y llama a la función encargada de hacerlo
process_event() {
    local action=$1
    local frequency=$2
    local date_field=$3
    local event_field=$4
    local temp_file=$5
    local days_span=$6
    local original_date
    local date
    local seq_limit

    case $frequency in
        "@puntual")
            date=$(echo $line | cut -d' ' -f"$date_field")
            event=$(echo $line | cut -d' ' -f"$event_field-")
            add_rm_event_to_date "$date" "$event" "$temp_file" "$action"
            ;;
        "@anual")
            month_day=$(echo $line | cut -d' ' -f"$date_field")
            event=$(echo $line | cut -d' ' -f"$event_field-")
            original_date="$(date +%Y)-$month_day"
            let seq_limit=($days_span/365)+1
            for i in $(seq -w 0 $seq_limit); do
                date=$(date -d "$original_date + $i years" +%Y-%m-%d)
                add_rm_event_to_date "$date" "$event" "$temp_file" "$action"
            done
            ;;
        "@mensual")
            day=$(echo $line | cut -d' ' -f"$date_field")
            event=$(echo $line | cut -d' ' -f"$event_field-")
            original_date=$(date -d "$current_date" +%Y-%m-$day)
            let seq_limit=($days_span/28)+1
            for i in $(seq -w 0 $seq_limit); do
                date=$(date -d "$original_date + $i months" +%Y-%m-%d)
                add_rm_event_to_date "$date" "$event" "$temp_file" "$action"
            done
            ;;
        "@semanal")
            weekday=$(translate_weekday "$(echo $line | cut -d' ' -f"$date_field")")
            event=$(echo $line | cut -d' ' -f"$event_field-")
            let seq_limit=($days_span/7)+1
            for week in $(seq 0 $seq_limit); do
                date=$(date -d "next $weekday + $week week" +%Y-%m-%d)
                add_rm_event_to_date "$date" "$event" "$temp_file" "$action"
            done
            ;;
    esac
}

# Función para mover eventos pasados a past.md
archive_past_events() {
    local line="$1"
    local past_file="$2"
    local temp_file="$3"
    local event_date=$(echo $line | cut -d' ' -f1)

    if [[ $event_date < $current_date ]]; then
        echo "$line" >> "$past_file"
        while IFS= read -r event_line; do
            if [[ $event_line =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]] || [[ -z $event_line ]]; then
                break
            fi
            echo "$event_line" >> "$past_file"
        done
        echo "" >> "$past_file"
    else
        echo "$line" >> "$temp_file"
    fi
}

# Función para extender el calendario hasta un número específico de días desde la fecha actual
extend_calendar() {
    local last_date="$1"
    local target_date="$2"
    local temp_file="$3"

    # Añadir una línea en blanco entre el último bloque existente y el primer bloque nuevo si es necesario
    last_line=$(tail -n -1 "$calendar_file")
    [[ "$last_line" != "" ]] && echo "" >> "$temp_file"

    # Añadir fechas hasta llegar al número de días especificado desde la fecha actual
    while [[ $last_date < $target_date ]]; do
        last_date=$(date -d "$last_date + 1 day" +%Y-%m-%d)
        day_of_week=$(date -d "$last_date" +%A)
        echo "$last_date $day_of_week" >> "$temp_file"
        echo "+ " >> "$temp_file"
        echo "" >> "$temp_file"
    done
}

process_calendar_and_past() {
    local calendar_file="$1"
    local past_file="$2"
    local events_file="$3"
    local days_to_add="$4"
    local current_date=$(date +%Y-%m-%d)
    local temp_file=$(mktemp)

    # Leer las cinco primeras líneas y mantenerlas en el archivo temporal
    head -n 5 "$calendar_file" > "$temp_file"

    # Leer el archivo calendar.md a partir de la sexta línea
    tail -n +6 "$calendar_file" | while IFS= read -r line; do
        if [[ $line =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
            archive_past_events "$line" "$past_file" "$temp_file"
        else
            echo "$line" >> "$temp_file"
        fi
    done

    # Obtener la última fecha en calendar.md
    local last_date=$(tail -n +6 "$calendar_file" | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}' | tail -n 1 | cut -d' ' -f1)

    # Calcular la fecha objetivo basada en el número de días a añadir
    local target_date=$(date -d "$current_date + $days_to_add days" +%Y-%m-%d)

    # Extender el calendario
    extend_calendar "$last_date" "$target_date" "$temp_file"

    # Añadir y eliminar eventos
    tail -n +3 "$events_file" | while IFS= read -r line; do
        if [[ $line =~ ^-\ \[\ \]\ @ ]]; then
            process_event "add" "$(echo $line | cut -d' ' -f4)" 5 6 "$temp_file" "$days_to_add"
        elif [[ $line =~ ^-\ \[X\]\ @ ]]; then
            process_event "rm" "$(echo $line | cut -d' ' -f3)" 4 5 "$temp_file" "$days_to_add"
        fi
    done

    # Reemplazar el archivo original con el archivo temporal
    mv "$temp_file" "$calendar_file"
}

process_events() {
    local events_file="$1"
    local temp_eventos_punt_vig=$(mktemp)
    local temp_eventos_rec_vig=$(mktemp)
    local temp_eventos_elim=$(mktemp)
    local temp_eventos_enquis=$(mktemp)

    # Leer las dos primeras líneas y mantenerlas en el archivo temporal
    head -n 2 "$events_file" > "$temp_eventos_punt_vig"

    # Leer el archivo events.md a partir de la tercera línea
    tail -n +3 "$events_file" | while IFS= read -r line; do
        if [[ $line =~ ^-\ \[\ \]\  ]]; then
            frequency=$(echo $line | cut -d' ' -f4)
            if [[ "$frequency" == "@puntual"  ]]; then
                echo "$line" >> "$temp_eventos_punt_vig"
            else
                echo "$line" >> "$temp_eventos_rec_vig"
            fi
        elif [[ $line =~ ^-\ \[X\]\  ]]; then
            echo "$line" >> "$temp_eventos_elim"
        elif [[ $line =~ ^-\ \[#\]\  ]]; then
            echo "$line" >> "$temp_eventos_enquis"
        fi
    done

    {
        echo ''
        echo '# Eventos Recurrentes'
        echo ''
        cat "$temp_eventos_rec_vig"
        echo ''
        echo '# Eventos Eliminados'
        echo ''
        sed -i "s/^-\ \[X\]\ /-\ \[#\]\ /g" "$temp_eventos_elim"
        cat "$temp_eventos_enquis"
        cat "$temp_eventos_elim"
    } >> "$temp_eventos_punt_vig"

    mv "$temp_eventos_punt_vig" "$events_file"
}

process_todo() {
    local todo_file="$1"
    local temp_tareas=$(mktemp)
    local temp_tareas_compl=$(mktemp)

    # Leer las dos primeras líneas y mantenerlas en el archivo temporal
    head -n 2 "$todo_file" > "$temp_tareas"

    # Leer el archivo todo.md a partir de la tercera línea
    tail -n +3 "$todo_file" | while IFS= read -r line; do
        if [[ $line =~ ^-\ \[\ \]\  ]]; then
            echo "$line" >> "$temp_tareas"
        elif [[ $line =~ ^-\ \[X\]\  ]]; then
            echo "$line" >> "$temp_tareas_compl"
        fi
    done

    {
        echo ''
        echo '# Tareas Completadas'
        echo ''
        cat "$temp_tareas_compl"
    } >> "$temp_tareas"

    mv "$temp_tareas" "$todo_file"
}

### ------------------ Fin de las declaraciones de funciones --------------------------

# Procesamos el archivo calendar.md, poniéndolo al día y archivando días pasados en past.md
process_calendar_and_past "$calendar_file" "$past_file" "$events_file" "$days_to_add"

# Y, ahora, vamos a encargarnos de ordenar los eventos ya marcados en events.md y dejarlos apropiadamente
process_events "$events_file"

# Y, ahora, vamos a encargarnos de procesar las tareas completadas de la lista todo.md
process_todo "$todo_file"

# Y, habiendo hecho ya todo, pasamos a abrir el index.md
vim $index_file
