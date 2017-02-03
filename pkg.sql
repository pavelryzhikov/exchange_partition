CREATE OR REPLACE PACKAGE SCHEME_NAME.PKG_NAME  authid CURRENT_USER  AS
/******************************************************************************
   NAME:       SCHEME_NAME.PKG_NAME
  description: пакет для работы с временными таблицами для exchange partition.



  имеется ряд ограничений:
  1) шаблон для имени партиции большой таблицы захардоржен в коде. 
      поскольку нет настройки в SCHEME_NAME.tab_ex_p_huge_settings
  2) требуется обязательное занесение настроек в таблицы SCHEME_NAME.tab_ex_p_huge_settings и SCHEME_NAME.tab_ex_p_small_settings
  3) 

  учтены следующие моменты:
      у таблицы есть индексы
      у таблицы есть NOT NULL constraints
      у таблицы есть PRIMARY KEY constraints 
        (аналогично должно работать для UK, FK, всех типов constraint из таблицы all_constraints). 
      У таблицы есть bitmap индексы
      У таблицы есть unused поля
      Решены вопросы с раздачей прав на таблицы

  соостветственно все остальные тонкости нужно добавлять.

  TODO:
  1) обработка ошибок. корректные сообщения.
  2) логи?  
  
  труктура SCHEME_NAME.tab_ex_p_small_settings
  SQL> desc SCHEME_NAME.tab_ex_p_small_settings
  Name             Type         Nullable Default    Comments                                                                                   
  ---------------- ------------ -------- ---------- ------------------------------------------------------------------------------------------ 
  OWNER            VARCHAR2(30)                     Схема исходной партициированной таблицы                                                    
  TAB_NAME         VARCHAR2(30)                     Имя исходной партициированной таблицы                                                      
  MASK_PREFIX      VARCHAR2(30)                     формат/префикс для имени таблицы                                                           
  MASK_DATE        VARCHAR2(30)          'YYYYMMDD' формат даты/партиции в имени таблицы                                                       
  SCHEMA_NAME_TRGT VARCHAR2(30) Y                   Схема для создания временных таблиц партициированной таблицы. по умолчанию схема источника 


   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        12.11.2016  Ryzhikov         1. Created this package.
   
******************************************************************************/



/*

description: pc_get_table_name
  техническая процедура. отдает информацию из настроечной таблицы SCHEME_NAME.tab_ex_p_small_settings
params:
  p_schema_name_src   - схема исходной таблицы, необязательны параметр. поиск таблицы ведется по имени. 
    если имя задвоено, нужно указать схему. для сокращения параметр сделан необязательным
  p_table_name_src    - имя исходной таблицы
  p_schema_name_trgt  - схема временной таблицы. необязательный параметр. поумолчанию считывается из 
    настречной таблицы. Полезен для кастомной загрузки
  p_date              - дата. указатель на партицию. предполагается партиционирование по датам.
  o_schema_name_src   - схема исходной таблицы. возвращаемое значение.
  o_schema_name_trgt  - имя временной таблицы. возвращаемое значение.
  o_table_name_trgt   - схема временной таблицы. возвращаемое значение.
  o_index_prefix      - префикс для именования индекса. возвращаемое значение.

*/
  procedure pc_get_table_name(
                              p_schema_name_src in varchar2 default null,
                              p_table_name_src in  varchar2,
                              p_schema_name_trgt in varchar2 default null,
                              p_date in date,
                              o_schema_name_src out varchar2,
                              o_schema_name_trgt out varchar2,
                              o_table_name_trgt out varchar2,
                              o_index_prefix out varchar2
                            );
  
/*

description: fn_get_table_name_full
  функция - обертка для pc_get_table_name.
return:
  отдает строку - полное наименование временной таблицы. типа [o_schema_name_trgt].[o_table_name_trgt]
  
*/
  function fn_get_table_name_full(
                              p_schema_name_src in varchar2 default null,
                              p_table_name_src in varchar2,
                              p_schema_name_trgt in varchar2 default null,
                              p_date in date
                            )
  return varchar2;

/*

description: fn_get_partition_name
  функция отдает имя партиции из настроечной таблицы SCHEME_NAME.tab_ex_p_huge_settings
params:
  p_schema_name_src   - схема исходной таблицы, необязательны параметр. поиск таблицы ведется по имени. 
    если имя задвоено, нужно указать схему. для сокращения параметр сделан необязательным
  p_table_name_src    - имя исходной таблицы
  p_date              - дата. указатель на партицию. предполагается партиционирование по датам.
return:
  имя партиции

*/
  function fn_get_partition_name(
                              p_schema_name_src in varchar2 default null,
                              p_table_name_src in varchar2,
                              p_date in date
                            )
  return varchar2;

/*

description: pc_create_table
  процедура. создает временную таблицу. 
    для именования индексов используется сиквенс SCHEME_NAME.tab_ex_p_small_settings_seq
params:
  p_schema_name_src   - схема исходной таблицы, необязательны параметр. поиск таблицы ведется по имени. 
    если имя задвоено, нужно указать схему. для сокращения параметр сделан необязательным
  p_table_name_src    - имя исходной таблицы
  p_schema_name_trgt  - схема временной таблицы. необязательный параметр. поумолчанию считывается из 
    настречной таблицы. Полезен для кастомной загрузки
  p_date              - дата. указатель на партицию. предполагается партиционирование по датам.
  
*/
  procedure pc_create_table(
                              p_schema_name_src in varchar2 default null,
                              p_table_name_src in varchar2,
                              p_schema_name_trgt in varchar2 default null,
                              p_date in date
                            );
/*

description: pc_drop_table
  процедура. удаляет временную таблицу
params:
  p_schema_name_src   - схема исходной таблицы, необязательны параметр. поиск таблицы ведется по имени. 
    если имя задвоено, нужно указать схему. для сокращения параметр сделан необязательным
  p_table_name_src    - имя исходной таблицы
  p_schema_name_trgt  - схема временной таблицы. необязательный параметр. поумолчанию считывается из 
    настречной таблицы. Полезен для кастомной загрузки
  p_date              - дата. указатель на партицию. предполагается партиционирование по датам.
  
*/
  procedure pc_drop_table(
                              p_schema_name_src in varchar2 default null,
                              p_table_name_src in varchar2,
                              p_schema_name_trgt in varchar2 default null,
                              p_date in date
                            );

/*

description: pc_exchange_partition
  процедура. обертка для xxx.Exchange_Partition
params:
  p_schema_name_src   - схема исходной таблицы, необязательны параметр. поиск таблицы ведется по имени. 
    если имя задвоено, нужно указать схему. для сокращения параметр сделан необязательным
  p_table_name_src    - имя исходной таблицы
  p_schema_name_trgt  - схема временной таблицы. необязательный параметр. поумолчанию считывается из 
    настречной таблицы. Полезен для кастомной загрузки
  p_date              - дата. указатель на партицию. предполагается партиционирование по датам.
  
*/
  procedure pc_exchange_partition(
                                  p_schema_name_src in varchar2 default null,
                                  p_table_name_src in varchar2,
                                  p_schema_name_trgt in varchar2 default null,
                                  p_date in date
                                );

                                                                                          
END;
/
CREATE OR REPLACE PACKAGE BODY SCHEME_NAME.PKG_NAME  AS

  procedure pc_get_table_name(
                              p_schema_name_src in varchar2 default null,
                              p_table_name_src in  varchar2,
                              p_schema_name_trgt in varchar2 default null,
                              p_date in date,
                              o_schema_name_src out varchar2,
                              o_schema_name_trgt out varchar2,
                              o_table_name_trgt out varchar2,
                              o_index_prefix out varchar2
                            )
  is    
    v_schema_name_src varchar2(255);
    v_schema_name_trgt varchar2(255);
    v_table_name_trgt varchar2(255);
    v_index_prefix varchar2(255);
    
  begin
  
    -- get partition name
      select 
        owner, COALESCE(p_schema_name_trgt, schema_NAME_TRGT,owner) schema_NAME_TRGT, MASK_PREFIX || to_char(p_date,MASK_DATE) table_name_trgt, MASK_PREFIX
        into v_schema_name_src, v_schema_name_trgt, v_table_name_trgt, v_index_prefix
      
      from SCHEME_NAME.tab_ex_p_small_settings
      where tab_name  = p_table_name_src
      and owner = nvl(p_schema_name_src,owner);

--      dbms_output.put_line('TABLE = '||v_schema_name_trgt || '.' || v_table_name_trgt);  
      
      o_schema_name_src   := v_schema_name_src;
      o_schema_name_trgt  := v_schema_name_trgt;
      o_table_name_trgt   := v_table_name_trgt;
      o_index_prefix      := v_index_prefix;
      
    exception when others then raise; -- NO_DATA_FOUND;
  END;                            


  function fn_get_table_name_full   (
                              p_schema_name_src in varchar2 default null,
                              p_table_name_src in varchar2,
                              p_schema_name_trgt in varchar2 default null,
                              p_date in date
                            )
  return varchar2
  is    
    
    v_schema_name_src varchar2(255);
    v_table_name_trgt varchar2(255);
    v_schema_name_trgt varchar2(255);
    v_index_prefix varchar2(255);
  begin
    pc_get_table_name( 
                                -- in
                                p_schema_name_src   => p_schema_name_src,
                                p_table_name_src    => p_table_name_src,
                                p_schema_name_trgt  => p_schema_name_trgt,
                                p_date              => p_date,
                                -- out
                                o_schema_name_src  => v_schema_name_src,
                                o_schema_name_trgt  => v_schema_name_trgt,
                                o_table_name_trgt   => v_table_name_trgt,
                                o_index_prefix      => v_index_prefix
                                );
                                
    return v_schema_name_trgt||'.'||v_table_name_trgt;

  end;  
  


  function fn_get_partition_name(
                              p_schema_name_src in varchar2 default null,
                              p_table_name_src in varchar2,
                              p_date in date
                            )
  return varchar2
  is    
    v_partition varchar2(255);
    v_partition_last varchar2(255);
    v_type_part integer;
  begin
  
-- try read SCHEME_NAME.tab_ex_p_big_settings. if table not exists then RAISE NO_DATA_FOUND

    
    -- get partition name
      select 
      LAST_PART_NAME,
      MASK_PART ||
      case 
        when type_part = 1 then to_char(p_date,'mm_yyyy')
        when type_part = 2 then null -- субпатиции. пока не понятно что делать.
        when type_part = 3 then to_char(p_date,'yyyy_mm_dd')
        when type_part = 4 then to_char(p_date,'yymm')
        when type_part = 5 then to_char(p_date,'mm_yyyy')
      else null
      end,
      type_part
      into v_partition_last, v_partition, v_type_part
      
      from SCHEME_NAME.tab_ex_p_huge_settings
      where tab_name  = p_table_name_src
      and owner = nvl(p_schema_name_src,owner);
      
      if v_type_part = 2 then
        -- TODO:
        -- пока не понятно что делать с субпатициями.
        raise VALUE_ERROR; 
      end if;
      
--      dbms_output.put_line('v_partition_last, v_partition = '||v_partition_last || ', ' || v_partition);  
      
      return v_partition;
      
    exception when others then raise; -- NO_DATA_FOUND;

    
  END;                            

  procedure pc_create_table(
                              p_schema_name_src in varchar2 default null,
                              p_table_name_src in varchar2,
                              p_schema_name_trgt in varchar2 default null,
                              p_date in date
                            )
  is    
    v_mess clob; 
    
    v_schema_name_src varchar2(255);
    v_schema_name_trgt varchar2(255);
    v_table_name_trgt varchar2(255);
    v_unused varchar2(4000);
    v_index_prefix varchar2(255);

    v_seq_next_val number;
  begin

    pc_get_table_name( 
                      -- in
                      p_schema_name_src   => p_schema_name_src,
                      p_table_name_src    => p_table_name_src,
                      p_schema_name_trgt  => p_schema_name_trgt,
                      p_date              => p_date,
                      -- out
                      o_schema_name_src   => v_schema_name_src,
                      o_schema_name_trgt  => v_schema_name_trgt,
                      o_table_name_trgt   => v_table_name_trgt,
                      o_index_prefix      => v_index_prefix
                      );

-- из-за unused колонок приходится генерировать скрипт по all_tab_cols. иначе можно было бы get_dll использовать.
-- NOT NULL добавляем на стадии create table, т.к. constraints для unusable полей не находятся в all_constraints

-- TODO: default value. для унйюзд дефолты пропадают.


    v_mess:=null;
    v_unused:=null;
    v_mess:= 'create table '||v_schema_name_trgt||'.'||v_table_name_trgt||' (';
     for i in (
          select 
                  case when hidden_column = 'YES' then '"'||atc.column_name || '"' else atc.column_name end column_name,
                  case when atc.INTERNAL_COLUMN_ID <> 1 then ',' else null end 
                  ||' '||
                  
                   case when hidden_column = 'YES' then '"'||atc.column_name || '"' else atc.column_name end
                  
                  || ' '||
                  case
                  when atc.data_type = 'DATE' then
                   'DATE'
                  when atc.data_type = 'NUMBER' and atc.DATA_LENGTH = 22 and
                       atc.DATA_PRECISION is null and atc.DATA_SCALE = 0 then
                   'INTEGER'
                  when atc.data_type = 'NUMBER' then
                   'NUMBER' || nvl2(atc.data_precision, '(' || atc.data_precision || ')', null)
                  else
                   atc.data_type || '(' || atc.data_length || ')'
                  end 
                  ||' '||
                  decode(nullable,'N',' NOT NULL ',null) ||'
                  ' --||chr(10)||chr(13)
                  field,
                  hidden_column
         from all_tab_cols  atc
         where atc.table_name = p_table_name_src
         and atc.owner = v_schema_name_src
        -- and  hidden_column = 'YES'
         order by atc.INTERNAL_COLUMN_ID
      )
      loop
        v_mess:=v_mess || i.field;
      
      end loop;
        v_mess:=v_mess || ') TABLESPACE "TABLESPACE_DATA"  ';
--        dbms_output.put_line( dbms_lob.substr( V_MESS, 32000, 1 ));         

------------------------------------------- old ceate table  
  if 1=0 then -- на время коментим. старый скрипт с использованием get_ddl
    dbms_metadata.set_transform_param (dbms_metadata.session_transform,'CONSTRAINTS', false);
    
    for i in (
      select DBMS_METADATA.GET_DDL('TABLE',p_table_name_src,v_schema_name_src) q from DUAL
    )
    loop
      V_MESS:=null;
    
      if instr(i.q, 'PARTITION BY') <> 0 then
        v_mess := substr(i.q,0,instr(i.q, 'PARTITION BY')-1); 
      else
        v_mess := i.q; 
      end if;      

      --if p_schema_name_trgt is not null then
      v_mess:= replace(v_mess,'"'|| v_schema_name_src ||'"', '"'|| v_schema_name_trgt ||'"');
      --end if;

      v_mess:= replace(v_mess,'"'|| p_table_name_src ||'"', '"'|| v_table_name_trgt ||'"');
      
--      dbms_output.put_line(V_MESS);       
    end loop;
  
    return;
  end if;
--------------------------------------------  

-- раздаем права для возможности запуска exchange partition
-- права для запуска ф-ии обвязки exch part
--- xxx - юзер где лежит ф-я обвязка

    execute immediate dbms_lob.substr( V_MESS, 32000, 1 );
    execute immediate 'grant alter on '|| v_schema_name_trgt || '.' || v_table_name_trgt ||' to xxx';
    execute immediate 'grant alter on '|| v_schema_name_src || '.' || p_table_name_src ||' to xxx';

    execute immediate 'grant select on '|| v_schema_name_trgt || '.' || v_table_name_trgt ||' to xxx';
    


---------------------- INDEX BLOCK ------------------
-- индексы уже можно достать с помощью get_ddl. 
-- имена индексов должны быть уникальны. для этого используется sequenсe SCHEME_NAME.tab_ex_p_small_settings
-- индекс имеет формат [YYY]I[XXXXXX], 
-- где [YYY] - префикс для временной таблицы.
-- [XXXXXX] - значение сиквенса дополненное нулями слева.

    
    for i in (
      select OWNER, INDEX_NAME from all_indexes 
      where owner = v_schema_name_src and table_name = p_table_name_src
    )
    loop

      for j in (
        select DBMS_METADATA.GET_DDL('INDEX',i.index_name,i.OWNER) q from DUAL
      )
      loop

        begin
          select SCHEME_NAME.tab_ex_p_small_settings_seq.nextval into v_seq_next_val  from dual; 
        exception when others then 
          -- TODO: create new sequence???
          raise;
        end;

        V_MESS:=null;
        if instr(j.q, '  LOCAL') <> 0 then
          v_mess:=substr(j.q,0,instr(j.q, '  LOCAL')-1);
          --dbms_output.put_line(substr(j.q,0,instr(j.q, '  LOCAL')-1));
        else
          v_mess:= j.q;
          --dbms_output.put_line(j.q);  
        end if;      

        --if p_schema_name_trgt is not null then
          v_mess:= replace(v_mess,'"'|| v_schema_name_src ||'"', '"'|| v_schema_name_trgt ||'"');
        --end if;

        v_mess:= replace(v_mess,'"'|| p_table_name_src ||'"', '"'|| v_table_name_trgt ||'"');
        v_mess:= replace(v_mess,'"'|| i.INDEX_NAME ||'"', '"'|| v_index_prefix || 'I'|| lpad(v_seq_next_val,6,'0') ||'"');

        
        --dbms_output.put_line(V_MESS);         
        execute immediate  dbms_lob.substr( V_MESS, 32000, 1 );

      end loop;

    end loop;

---------------------- all_constraints BLOCK ------------------
-- добавляем primary key, etc. 
-- NOT NULL уже есть. поэтому ошибки в execute пропускаем. 
-- NOT NULL добавляем на стадии create table, т.к. constraints для unusable полей не находятся в all_constraints

    for i in (
      select OWNER, CONSTRAINT_NAME from all_constraints 
      where owner = v_schema_name_src and table_name = p_table_name_src
    )
    loop

      for j in (
        select DBMS_METADATA.GET_DDL('CONSTRAINT',i.CONSTRAINT_NAME,i.OWNER) q from DUAL
      )
      loop

        V_MESS:=null;
        if instr(j.q, '  LOCAL') <> 0 then
          v_mess:=substr(j.q,0,instr(j.q, '  LOCAL')-1);
          --dbms_output.put_line(substr(j.q,0,instr(j.q, '  LOCAL')-1));
        else
          v_mess:= j.q;
          --dbms_output.put_line(j.q);  
        end if;      

        --if p_schema_name_trgt is not null then
          v_mess:= replace(v_mess,'"'|| v_schema_name_src ||'"', '"'|| v_schema_name_trgt ||'"');
        --end if;

        v_mess:= replace(v_mess,'"'|| p_table_name_src ||'"', '"'|| v_table_name_trgt ||'"');
--        dbms_output.put_line(V_MESS);         
        begin
          execute immediate  dbms_lob.substr( V_MESS, 32000, 1 );
        exception when others then null; -- ошибки повторного наката NOT NULL
        end;
        
      end loop;

    end loop;

---------------------- add unused columns BLOCK ------------------
-- переводим "unused" колонки в статус UNUSED. до этого они были обычными колонками.

--  alter table T add "SYS_C00004_15112316:09:36$" NUMBER  
--  alter table T set unused column "SYS_C00004_15112316:09:36$"
      for i in (
          select atc.column_name
         from all_tab_cols  atc
         where atc.table_name = p_table_name_src
         and atc.owner = v_schema_name_src
         and  hidden_column = 'YES'
         order by column_id
      )
      loop
         v_unused :=  'alter table '||v_schema_name_trgt||'.'||v_table_name_trgt || 
         ' set unused column "'||i.column_name||'"';     
--         dbms_output.put_line(v_unused);         
         execute immediate v_unused;         
        
      end loop;
  exception when others then raise;
  end;


  procedure pc_drop_table(
                              p_schema_name_src in varchar2 default null,
                              p_table_name_src in varchar2,
                              p_schema_name_trgt in varchar2 default null,
                              p_date in date
                            )
  is    
    v_table_name_trgt_full varchar2(255);
  begin

    v_table_name_trgt_full := fn_get_table_name_full( 
                                -- in
                                p_schema_name_src   => p_schema_name_src,
                                p_table_name_src    => p_table_name_src,
                                p_schema_name_trgt  => p_schema_name_trgt,
                                p_date              => p_date
                                );

    begin 
      execute immediate 'drop table '|| v_table_name_trgt_full;
    exception when others then
      --TODO: в случае отдельно sequence удаляем sequence 
      --null;
      raise;
    end;

  exception when others then raise;
  end;


  procedure pc_exchange_partition(
                                  p_schema_name_src in varchar2 default null,
                                  p_table_name_src in varchar2,
                                  p_schema_name_trgt in varchar2 default null,
                                  p_date in date
                                )
  is    
    v_partition varchar2(255);
    v_mess varchar2(255); 
    
    v_schema_name_src varchar2(255);
    v_schema_name_trgt varchar2(255);
    v_table_name_trgt varchar2(255);
    v_index_prefix varchar2(255);

  begin

    v_partition := fn_get_partition_name( p_schema_name_src   =>p_schema_name_src,
                                          p_table_name_src    =>p_table_name_src,
                                          --p_schema_name_trgt  =>p_schema_name_trgt,
                                          p_date              =>p_date);

    pc_get_table_name( 
                                -- in
                                p_schema_name_src   => p_schema_name_src,
                                p_table_name_src    => p_table_name_src,
                                p_schema_name_trgt  => p_schema_name_trgt,
                                p_date              => p_date,
                                -- out
                                o_schema_name_src   => v_schema_name_src,
                                o_schema_name_trgt  => v_schema_name_trgt,
                                o_table_name_trgt   => v_table_name_trgt,
                                o_index_prefix      => v_index_prefix
                                );
-- отключаем bitmap индексы на источнике и таргете. только для нужной партиции
--ALTER INDEX III  MODIFY PARTITION P_1 UNUSABLE; --  исходная таблица
--ALTER INDEX III_temp UNUSABLE;                  --  временная таблица
--exchange partition *** 
--alter index III rebuild partition P_1;          --  включаем индекс на источнике обратно

    for i in (
      select OWNER, INDEX_NAME from all_indexes 
      where (
      (owner =  v_schema_name_src and table_name = p_table_name_src) 
      )
      and index_type = 'BITMAP'
    )
    loop
        v_mess:='ALTER INDEX '||i.owner||'.'||i.index_name||' MODIFY PARTITION '||v_partition||' UNUSABLE';
--        dbms_output.put_line(V_MESS);         
        execute immediate  dbms_lob.substr( V_MESS, 32000, 1 );
    end loop;


    for i in (
      select OWNER, INDEX_NAME from all_indexes 
      where (
      (owner =  v_schema_name_trgt and table_name = v_table_name_trgt) 
      )
      and index_type = 'BITMAP'
    )
    loop
        v_mess:='ALTER INDEX '||i.owner||'.'||i.index_name||' UNUSABLE';
--        dbms_output.put_line(V_MESS);         
        execute immediate  dbms_lob.substr( V_MESS, 32000, 1 );
    end loop;

    begin 
     -- запуск обвязки. реализует стандартный функционал. только через параметр
     -- TODO: написать свою.
     
      xxx.Exchange_Partition( 
                              pSchemeName => v_schema_name_src,
                              pTableName => p_table_name_src,
                              pPartitionName => v_partition,
                              pTmpSchemeName => v_schema_name_trgt,
                              pTmpTableName  => v_table_name_trgt,
                              pIndexAction => 'ii'
                             ); 
    end;

    for i in (
      select OWNER, INDEX_NAME from all_indexes 
      where (
      (owner =  v_schema_name_src and table_name = p_table_name_src) 
      )
      and index_type = 'BITMAP'
    )
    loop
        v_mess:='ALTER INDEX '||i.owner||'.'||i.index_name||' rebuild partition '||v_partition;
--        dbms_output.put_line(V_MESS);         
        execute immediate  dbms_lob.substr( V_MESS, 32000, 1 );
    end loop;
   
  exception when others then raise;
  end;



END ;
/
