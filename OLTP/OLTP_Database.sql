/*==============================================================*/
/* Table: PUNTO                                                 */
/*==============================================================*/
create table PUNTO
(
   ID_PUNTO             VARCHAR2(6)          not null,
   DIRECCION_PUNTO      VARCHAR2(100),
   CIUDAD_PUNTO         VARCHAR2(50),
   REGION_PUNTO         VARCHAR2(50),
   ZONA_PUNTO           VARCHAR2(15),
   CODIGO_POSTAL        VARCHAR2(15),
   constraint PK_PUNTO primary key (ID_PUNTO)
);

/*==============================================================*/
/* Table: CENTRO_LOGISTICO                                      */
/*==============================================================*/
create table CENTRO_LOGISTICO
(
   ID_CENTRO            VARCHAR2(6)          not null,
   ID_PUNTO             VARCHAR2(6)          not null,
   NOMBRE_CENTRO        VARCHAR2(50),
   constraint PK_CENTRO_LOGISTICO primary key (ID_CENTRO)
);

/*==============================================================*/
/* Index: POSEE_FK                                              */
/*==============================================================*/
create index POSEE_FK on CENTRO_LOGISTICO (
   ID_PUNTO ASC
);

/*==============================================================*/
/* Table: TIPO_CARGA                                            */
/*==============================================================*/
create table TIPO_CARGA
(
   ID_TIPO_CARGA        VARCHAR2(6)          not null,
   NOMBRE_TIPO_CARGA    VARCHAR2(30),
   DESCRIPCION_TIPO_CARGA VARCHAR2(500),
   constraint PK_TIPO_CARGA primary key (ID_TIPO_CARGA)
);

/*==============================================================*/
/* Table: CLIENTE                                               */
/*==============================================================*/
create table CLIENTE
(
   ID_CLIENTE           VARCHAR2(6)          not null,
   ID_PUNTO             VARCHAR2(6)          not null,
   NOMBRE_CLIENTE       VARCHAR2(50),
   RUT_CLIENTE          VARCHAR2(9),
   TELEFONO_CLIENTE     NUMBER(15),
   TIPO_CLIENTE         VARCHAR2(20),
   constraint PK_CLIENTE primary key (ID_CLIENTE)
);

/*==============================================================*/
/* Index: TIENE_FK                                              */
/*==============================================================*/
create index TIENE_FK on CLIENTE (
   ID_PUNTO ASC
);

/*==============================================================*/
/* Table: VEHICULO                                              */
/*==============================================================*/
create table VEHICULO
(
   PATENTE_VEHICULO     VARCHAR2(6)          not null,
   TIPO_VEHICULO        VARCHAR2(30),
   MODELO_VEHICULO      VARCHAR2(30),
   CAPACIDAD_TONELADA   NUMBER(5, 2),
   CONSUMO_COMBUSTIBLE  FLOAT(5),
   ESTADO_VEHICULO      VARCHAR2(30),
   constraint PK_VEHICULO primary key (PATENTE_VEHICULO)
);

/*==============================================================*/
/* Table: DESPACHO                                              */
/*==============================================================*/
create table DESPACHO
(
   ID_DESPACHO          VARCHAR2(6)          not null,
   ID_CLIENTE           VARCHAR2(6)          not null,
   PATENTE_VEHICULO     VARCHAR2(6)          not null,
   FECHA_SALIDA_ESTIMADA DATE,
   FECHA_LLEGADA_ESTIMADA DATE,
   FECHA_SALIDA_REAL    DATE,
   FECHA_LLEGADA_REAL   DATE,
   PESO_CARGA_TONELADAS NUMBER(10, 2),
   ESTADO_DESPACHO      VARCHAR2(30),
   OBSERVACIONES_DESPACHO VARCHAR2(500),
   COMBUSTIBLE_CONSUMIDO NUMBER(5),
   COSTO_COMBUSTIBLE_L  NUMBER(15),
   COSTO_PEAJE_REAL     NUMBER(7),
   OTROS_COSTOS         NUMBER(10),
   constraint PK_DESPACHO primary key (ID_DESPACHO)
);

/*==============================================================*/
/* Index: SOLICITA_FK                                           */
/*==============================================================*/
create index SOLICITA_FK on DESPACHO (
   ID_CLIENTE ASC
);

/*==============================================================*/
/* Index: ES_ASIGNADO_A_FK                                      */
/*==============================================================*/
create index ES_ASIGNADO_A_FK on DESPACHO (
   PATENTE_VEHICULO ASC
);

/*==============================================================*/
/* Table: CLASIFICA_A (Tabla intermedia Despacho <-> Tipo Carga)*/
/*==============================================================*/
create table CLASIFICA_A
(
   ID_DESPACHO          VARCHAR2(6)          not null,
   ID_TIPO_CARGA        VARCHAR2(6)          not null,
   constraint PK_CLASIFICA_A primary key (ID_DESPACHO, ID_TIPO_CARGA)
);

/*==============================================================*/
/* Table: RUTA_DEFINIDA                                         */
/*==============================================================*/
create table RUTA_DEFINIDA
(
   ID_RUTA              VARCHAR2(6)          not null,
   ID_PUNTO_ORIGEN      VARCHAR2(6)          not null, -- CORREGIDO Y RENOMBRADO
   ID_PUNTO_DESTINO     VARCHAR2(6)          not null, -- CORREGIDO Y RENOMBRADO
   NOMBRE_RUTA          VARCHAR2(50),
   DISTANCIA_ESTIMADA_KM NUMBER(6),
   HORAS_ESTIMADAS      NUMBER(5),
   COSTO_PEAJE_ESTIMADO NUMBER(7),
   OBSERVACIONES_RUTAS  VARCHAR2(500),
   constraint PK_RUTA_DEFINIDA primary key (ID_RUTA)
);

/*==============================================================*/
/* Index: ES_DESTINO_EN_FK                                      */
/*==============================================================*/
create index ES_DESTINO_EN_FK on RUTA_DEFINIDA (
   ID_PUNTO_DESTINO ASC
);

/*==============================================================*/
/* Index: ES_ORIGEN_EN_FK                                       */
/*==============================================================*/
create index ES_ORIGEN_EN_FK on RUTA_DEFINIDA (
   ID_PUNTO_ORIGEN ASC
);

/*==============================================================*/
/* Table: PERTENECE (Tabla intermedia Despacho <-> Ruta)        */
/*==============================================================*/
create table PERTENECE
(
   ID_DESPACHO          VARCHAR2(6)          not null,
   ID_RUTA              VARCHAR2(6)          not null,
   constraint PK_PERTENECE primary key (ID_DESPACHO, ID_RUTA)
);

/*==============================================================*/
/* Table: TRABAJADOR                                            */
/*==============================================================*/
create table TRABAJADOR
(
   RUT_TRABAJADOR       VARCHAR2(9)          not null,
   NOMBRE_TRABAJADOR    VARCHAR2(30),
   APELLIDO_TRABAJADOR  VARCHAR2(30),
   TIPO_LICENCIA        VARCHAR2(3),
   TELEFONO_TRABAJADOR  NUMBER(15),
   ESTADO_TRABAJADOR    VARCHAR2(30),
   TIPO_TRABAJADOR      VARCHAR2(20),
   constraint PK_TRABAJADOR primary key (RUT_TRABAJADOR)
);

/*==============================================================*/
/* Table: REALIZA (Tabla intermedia Despacho <-> Trabajador)    */
/*==============================================================*/
create table REALIZA
(
   ID_DESPACHO          VARCHAR2(6)          not null,
   RUT_TRABAJADOR       VARCHAR2(9)          not null,
   constraint PK_REALIZA primary key (ID_DESPACHO, RUT_TRABAJADOR)
);

/*==============================================================*/
/* Foreign Key Constraints                                      */
/*==============================================================*/

alter table CENTRO_LOGISTICO
   add constraint FK_CENTRO_L_POSEE_PUNTO foreign key (ID_PUNTO)
      references PUNTO (ID_PUNTO);

alter table CLASIFICA_A
   add constraint FK_CLASIFIC_CLASIFICA_DESPACHO foreign key (ID_DESPACHO)
      references DESPACHO (ID_DESPACHO);

alter table CLASIFICA_A
   add constraint FK_CLASIFIC_CLASIFICA_TIPO_CAR foreign key (ID_TIPO_CARGA)
      references TIPO_CARGA (ID_TIPO_CARGA);

alter table CLIENTE
   add constraint FK_CLIENTE_TIENE_PUNTO foreign key (ID_PUNTO)
      references PUNTO (ID_PUNTO);

alter table DESPACHO
   add constraint FK_DESPACHO_ES_ASIGNA_VEHICULO foreign key (PATENTE_VEHICULO)
      references VEHICULO (PATENTE_VEHICULO);

alter table DESPACHO
   add constraint FK_DESPACHO_SOLICITA_CLIENTE foreign key (ID_CLIENTE)
      references CLIENTE (ID_CLIENTE);

alter table PERTENECE
   add constraint FK_PERTENEC_PERTENECE_DESPACHO foreign key (ID_DESPACHO)
      references DESPACHO (ID_DESPACHO);

alter table PERTENECE
   add constraint FK_PERTENEC_PERTENECE_RUTA_DEF foreign key (ID_RUTA)
      references RUTA_DEFINIDA (ID_RUTA);

alter table REALIZA
   add constraint FK_REALIZA_REALIZA_DESPACHO foreign key (ID_DESPACHO)
      references DESPACHO (ID_DESPACHO);

alter table REALIZA
   add constraint FK_REALIZA_REALIZA2_TRABAJAD foreign key (RUT_TRABAJADOR)
      references TRABAJADOR (RUT_TRABAJADOR);

alter table RUTA_DEFINIDA
   add constraint FK_RUTA_DEF_ES_DESTIN_PUNTO foreign key (ID_PUNTO_DESTINO)
      references PUNTO (ID_PUNTO);

alter table RUTA_DEFINIDA
   add constraint FK_RUTA_DEF_ES_ORIGEN_PUNTO foreign key (ID_PUNTO_ORIGEN)
      references PUNTO (ID_PUNTO);
