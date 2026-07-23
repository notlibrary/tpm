package require Tk
package require ttk

# 1. Проверка и загрузка драйвера PostgreSQL
set pg_available 0
if {[catch {
    package require tdbc::postgres
    set pg_available 1
} err]} {
    tk_messageBox -icon error -title "Ошибка драйвера" \
        -message "Не удалось загрузить tdbc::postgres.\nУбедитесь, что пакет tdbc::postgres установлен.\nДетали: $err"
    exit 1
}

# Функция гарантирует точное побайтовое хеширование без скрытых переносов строк Windows
proc native_sha256 {input_string} {
    set tmp_file "tmp_hash_input.bin"
    
    set fh [open $tmp_file w]
    fconfigure $fh -translation binary -encoding utf-8
    puts -nonewline $fh $input_string
    close $fh

    set hash ""
    if {![catch {exec certutil -hashfile $tmp_file SHA256} output]} {
        set lines [split [string trim $output] "\n"]
        if {[llength $lines] >= 2} {
            set hash [string map {" " "" "\r" "" "\n" ""} [lindex $lines 1]]
        }
    }
    
    file delete -force $tmp_file
    return [string tolower $hash]
}

# 2. Конфигурация подключения к БД
# Укажите ваши реальные доступы к PostgreSQL ниже:
array set db_config {
    host     "localhost"
    port     5433
    user     "postgres"
    password "arizona42"
    database "toothpastes"
}

# 3. Функция проверки учетных данных в БД (Только чтение, БЕЗ UPDATE)
proc authenticate_user {username password} {
    global db_config
    set authenticated 0
    
    if {[catch {
        tdbc::postgres::connection create db \
            -host $db_config(host) \
            -port $db_config(port) \
            -user $db_config(user) \
            -password $db_config(password) \
            -database $db_config(database)
    } conn_err]} {
        tk_messageBox -icon error -title "Ошибка БД" -message "Не удалось подключиться к базе данных:\n$conn_err"
        return 0
    }
    
    set query {
        SELECT user_id, password_hash, salt 
        FROM tp_users 
        WHERE username = :username AND is_active = true
    }
    
    if {[catch {
        set statement [db prepare $query]
        set resultset [$statement execute [dict create username $username]]
        
        if {[$resultset nextrow row]} {
            set user_id [dict get $row user_id]
            set db_hash [string tolower [string trim [dict get $row password_hash]]]
            set db_salt [string trim [dict get $row salt]]
            
            # Проверка 1: Чистый хэш от пароля (актуально для вашего аккаунта admin)
            set hash_pure_password [native_sha256 $password]
            
            # Проверка 2: Хэш по схеме Пароль + Соль (на будущее для безопасных записей)
            set hash_with_salt [native_sha256 "${password}${db_salt}"]
            
            # Если совпал любой из вариантов — авторизация пройдена успешно
            if {$hash_pure_password eq $db_hash || $hash_with_salt eq $db_hash} {
                set authenticated $user_id
            }
        }
        $resultset close
        $statement close
    } execution_err]} {
        tk_messageBox -icon error -title "Ошибка SQL" -message "Ошибка при выполнении запроса:\n$execution_err"
    }
    
    db close
    return $authenticated
}

# 4. Обработчик нажатия кнопки "Войти"
proc handle_login {} {
    global login_user login_pass
    
    set user [string trim $login_user]
    set pass $login_pass
    
    if {$user eq "" || $pass eq ""} {
        tk_messageBox -icon warning -title "Внимание" -message "Пожалуйста, заполните все поля."
        return
    }
    
    set auth_result [authenticate_user $user $pass]
    
    if {$auth_result > 0} {
        tk_messageBox -icon info -title "Успех" -message "Авторизация успешна!\nID пользователя: $auth_result"
        # Для закрытия окна авторизации после успеха раскомментируйте строку ниже:
        # destroy .
    } else {
        tk_messageBox -icon error -title "Отказ" -message "Неверное имя пользователя или пароль."
    }
}

# 5. Построение графического интерфейса (GUI) с использованием Ttk
wm title . "Авторизация в системе Toothpastes"
wm geometry . "320x180"
wm resizable . 0 0

set login_user ""
set login_pass ""

set f [ttk::frame .main_frame -padding 15]
pack $f -fill both -expand 1

ttk::label $f.lbl_user -text "Имя пользователя:" -anchor w
ttk::entry $f.ent_user -textvariable login_user -width 30
pack $f.lbl_user -fill x -pady {0 2}
pack $f.ent_user -fill x -pady {0 10}

ttk::label $f.lbl_pass -text "Пароль:" -anchor w
ttk::entry $f.ent_pass -textvariable login_pass -show "*" -width 30
pack $f.lbl_pass -fill x -pady {0 2}
pack $f.ent_pass -fill x -pady {0 15}

ttk::button $f.btn_login -text "Войти в систему" -command handle_login -default active
pack $f.btn_login -fill x -ipady 3

bind . <Return> {handle_login}
focus $f.ent_user
