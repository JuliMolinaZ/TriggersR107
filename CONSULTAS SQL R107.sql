-- TRIGGER

CREATE TRIGGER trg_update_recolectado_picklist
BEFORE UPDATE ON PickListDetalle
FOR EACH ROW
BEGIN
    DECLARE nueva_cantidad_restante INT;
    DECLARE nuevo_status_producto VARCHAR(10);
    DECLARE current_stock INT;

    -- Verificar si Recolectado es impar (1, 3, 5, 7, etc.) al momento de la actualización
    IF NEW.Recolectado % 2 = 1 THEN
    	-- Actualizar SurtidoAcumulado con el valor de CantidadSurtida enviada
        SET NEW.SurtidoAcumulado = NEW.CantidadSurtida;  
        
        -- Sumar CantidadSurtida a la cantidad previamente surtida
        SET NEW.CantidadSurtida = OLD.CantidadSurtida + NEW.CantidadSurtida;

        -- Calcular la cantidad restante 
        SET nueva_cantidad_restante = GREATEST(OLD.CantidadRequerida - NEW.CantidadSurtida, 0);

        -- Determinar el nuevo status del producto
        IF nueva_cantidad_restante = 0 AND NEW.CantidadSurtida >= OLD.CantidadRequerida THEN
            SET nuevo_status_producto = 'Total';
        ELSE
            SET nuevo_status_producto = 'Parcial';
        END IF;

        -- Asignar los valores a NEW
        SET NEW.CantidadRestante = nueva_cantidad_restante;
        SET NEW.StatusProducto = nuevo_status_producto;

        -- Actualizar StatusPickList en PickList si el StatusProducto es 'Parcial' o 'Total'
        IF nuevo_status_producto IN ('Parcial', 'Total') THEN
            UPDATE PickList
            SET StatusPickList = 'Recolectado'
            WHERE PickListID = NEW.PickListID;
        END IF;
        
        SELECT Stock INTO current_stock
        FROM ProductosUbicacion
        WHERE ProductoID = NEW.ProductoID AND UbicacionID = NEW.UbicacionID;

        -- Actualizacion Stock
        UPDATE ProductosUbicacion
        SET Stock = Stock - NEW.SurtidoAcumulado
        WHERE ProductoID = NEW.ProductoID AND UbicacionID = NEW.UbicacionID;

        -- Insertar en la tabla de logs
        INSERT INTO LogsSurtido (
            NewRecolectado, NewStock, NewSurtidoAcumulado, 
            OldRecolectado, OldStock, OldSurtidoAcumulado, 
            OperationDate, PickListDetalleID, ProductoID
        ) 
        VALUES (
            NEW.Recolectado, 
            (SELECT Stock FROM ProductosUbicacion WHERE ProductoID = NEW.ProductoID AND UbicacionID = NEW.UbicacionID), 
            NEW.SurtidoAcumulado, 
            OLD.Recolectado, 
            current_stock, 
            OLD.SurtidoAcumulado, 
            NOW(), 
            NEW.PickListDetalleID, 
            NEW.ProductoID
        );

        -- Pasar Recolectado al siguiente número par
        SET NEW.Recolectado = NEW.Recolectado + 1;

    ELSE
        -- Si Recolectado es par, eliminar el valor de SurtidoAcumulado
        SET NEW.SurtidoAcumulado = NULL; 
    END IF;

END;



-- PRUEBAS
 
-- Prueba 1
UPDATE PickListDetalle 
SET CantidadSurtida = 10, Recolectado = 1 
WHERE PickListID = 'PL100' AND UbicacionID = 'UB100';

SELECT * FROM `PickListDetalle` WHERE PickListID = 'PL100' AND UbicacionID = 'UB100';

SELECT * FROM `ProductosUbicacion` WHERE ProductoID = 'PRD100' AND UbicacionID = 'UB100';



-- Prueba 2
UPDATE PickListDetalle 
SET CantidadSurtida = 2, Recolectado = 3 
WHERE PickListID = 'PL100' AND UbicacionID = 'UB100';

SELECT * FROM `PickListDetalle` WHERE PickListID = 'PL100' AND UbicacionID = 'UB100';

SELECT * FROM `ProductosUbicacion` WHERE ProductoID = 'PRD100' AND UbicacionID = 'UB100';

-- Prueba 3

UPDATE PickListDetalle 
SET CantidadSurtida = 13, Recolectado = 5 
WHERE PickListID = 'PL100' AND UbicacionID = 'UB100';

SELECT * FROM `PickListDetalle` WHERE PickListID = 'PL100' AND UbicacionID = 'UB100';

SELECT * FROM `ProductosUbicacion` WHERE ProductoID = 'PRD100' AND UbicacionID = 'UB100';



-- ACTUALIZACIONES VALORES 0


UPDATE PickListDetalle SET CantidadSurtida = 0, Recolectado = 0, StatusProducto = 'Pendiente', CantidadRestante = 25 WHERE PickListID = 'PL100' AND UbicacionID = 'UB100';
SELECT * FROM `PickListDetalle` WHERE PickListID = 'PL100' AND UbicacionID = 'UB100';


SELECT * FROM `ProductosUbicacion` WHERE ProductoID = 'PRD100' AND UbicacionID = 'UB100';





